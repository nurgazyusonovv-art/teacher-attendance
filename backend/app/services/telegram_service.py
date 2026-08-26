import logging
from datetime import date, datetime
from typing import Optional, Tuple
import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.utils import current_time_in_school_timezone, today_date_in_school_timezone
from app.models.school import School
from app.services.attendance_service import AttendanceService

logger = logging.getLogger("telegram_service")


class TelegramService:
    @staticmethod
    async def send_message(
        bot_token: str,
        chat_id: str,
        text: str,
        parse_mode: str = "HTML",
    ) -> Tuple[bool, Optional[str]]:
        """
        Sends an HTML or Markdown message to a Telegram chat/channel/group via Bot API.
        """
        if not bot_token or not chat_id:
            return False, "Bot Token же Chat ID көрсөтүлгөн эмес"

        url = f"https://api.telegram.org/bot{bot_token.strip()}/sendMessage"
        payload = {
            "chat_id": chat_id.strip(),
            "text": text,
            "parse_mode": parse_mode,
            "disable_web_page_preview": True,
        }

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(url, json=payload)
                data = response.json()
                if response.status_code == 200 and data.get("ok"):
                    logger.info(f"Telegram message successfully sent to {chat_id}")
                    return True, None
                
                err_desc = data.get("description") or f"HTTP {response.status_code}"
                logger.error(f"Telegram API error: {err_desc}")
                return False, f"Telegram катасы: {err_desc}"
        except httpx.RequestError as e:
            logger.error(f"Telegram network error: {e}")
            return False, f"Телеграмга туташуу катасы: {e}"
        except Exception as e:
            logger.error(f"Unexpected Telegram error: {e}")
            return False, str(e)

    @staticmethod
    async def generate_daily_attendance_report(
        db: AsyncSession,
        school_id: str,
        target_date: Optional[date] = None,
    ) -> Tuple[str, School]:
        """
        Generates a comprehensive, human-readable Kyrgyz daily attendance report in HTML format.
        """
        school_res = await db.execute(select(School).where(School.id == school_id))
        school = school_res.scalar_one()

        query_date = target_date or today_date_in_school_timezone(school.timezone)
        dashboard = await AttendanceService.get_admin_today_dashboard(db, school_id, query_date)

        total = dashboard.total_teachers
        checked_in = dashboard.checked_in_count
        on_time = dashboard.on_time_count
        late_count = dashboard.late_count
        not_checked_in = dashboard.not_checked_in_count
        records = dashboard.records

        # Format Kyrgyz date
        month_names = {
            1: "январь", 2: "февраль", 3: "март", 4: "апрель",
            5: "май", 6: "июнь", 7: "июль", 8: "август",
            9: "сентябрь", 10: "октябрь", 11: "ноябрь", 12: "декабрь",
        }
        weekdays = {
            0: "дүйшөмбү", 1: "шейшемби", 2: "шаршемби",
            3: "бейшемби", 4: "жума", 5: "ишемби", 6: "жекшемби",
        }
        day_str = f"{query_date.day}-{month_names.get(query_date.month, '')} {query_date.year}, {weekdays.get(query_date.weekday(), '')}"

        att_pct = f"{int((checked_in / total) * 100)}%" if total > 0 else "0%"
        now_time = current_time_in_school_timezone(school.timezone).strftime("%H:%M")

        # Build report
        lines = [
            f"🏫 <b>{school.name}</b>",
            f"📋 <b>Мугалимдердин катышуусу боюнча күндөлүк отчет</b>",
            f"📅 <b>Күнү:</b> {day_str}",
            "",
            "📊 <b>Жалпы көрсөткүчтөр:</b>",
            f"• Бардык мугалимдер: <b>{total}</b>",
            f"• Келгендер: <b>{checked_in}</b> ({att_pct})",
            f"• Өз убагында: <b>{on_time}</b>",
            f"• Кечиккендер: <b>{late_count}</b>",
            f"• Келбегендер: <b>{not_checked_in}</b>",
        ]

        # Late teachers section
        late_records = [
            r for r in records
            if r.status == "LATE" or (r.total_late_minutes or 0) > 0 or (r.late_minutes or 0) > 0
        ]
        if late_records:
            lines.append("")
            lines.append("⏰ <b>Кечиккен мугалимдер:</b>")
            for idx, r in enumerate(late_records, 1):
                name = r.teacher_name or "Мугалим"
                subj = f" ({r.subject})" if r.subject else ""
                lines.append(f"{idx}. 👤 <b>{name}</b>{subj}")
                if r.late_minutes and r.late_minutes > 0:
                    check_in_str = r.check_in_time.strftime("%H:%M") if r.check_in_time else "--:--"
                    lines.append(f"   └ <i>Эртең менен келүүсү: {check_in_str} (+{r.late_minutes} мүн)</i>")
                for d in r.lesson_delays:
                    reason_str = f" — «{d.reason}»" if d.reason else ""
                    lines.append(f"   └ <i>{d.lesson_number}-сабак: +{d.delay_minutes} мүн кечиккен{reason_str}</i>")
                if (r.total_late_minutes or 0) > 0:
                    lines.append(f"   └ <b>Жалпы кечигүү: +{r.total_late_minutes} мүнөт</b>")

        # Absent teachers section
        absent_records = [r for r in records if r.check_in_time is None or r.status == "ABSENT"]
        if absent_records:
            lines.append("")
            lines.append("🚶 <b>Келбеген мугалимдер:</b>")
            for idx, r in enumerate(absent_records, 1):
                name = r.teacher_name or "Мугалим"
                subj = f" ({r.subject})" if r.subject else ""
                lines.append(f"{idx}. 👤 <b>{name}</b>{subj} — <i>Келген жок</i>")
        else:
            lines.append("")
            lines.append("🎉 <i>Бардык мугалимдер толук келишти!</i>")

        lines.append("")
        lines.append(f"⏱ <i>Отчет түзүлгөн убакыт: {now_time} ({school.timezone})</i>")
        lines.append("🤖 <i>School Attendance Bot</i>")

        report_text = "\n".join(lines)
        return report_text, school

    @staticmethod
    async def send_daily_report(
        db: AsyncSession,
        school_id: str,
        target_date: Optional[date] = None,
        override_bot_token: Optional[str] = None,
        override_chat_id: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[str]]:
        """
        Generates and transmits the daily attendance report to the configured Telegram chat.
        """
        report_text, school = await TelegramService.generate_daily_attendance_report(
            db, school_id, target_date
        )

        bot_token = override_bot_token or school.telegram_bot_token or getattr(settings, "TELEGRAM_BOT_TOKEN", None)
        chat_id = override_chat_id or school.telegram_chat_id or getattr(settings, "TELEGRAM_CHAT_ID", None)

        if not bot_token or not chat_id:
            return False, "Мектептин Telegram Bot Token же Chat ID маалыматтары коюлган эмес. Жөндөөлөрдөн кошуңуз.", report_text

        success, err = await TelegramService.send_message(bot_token, chat_id, report_text)
        if success:
            return True, "Күндөлүк отчет Telegram каналына/чатына ийгиликтүү жөнөтүлдү! 🚀", report_text
        return False, err or "Telegram'га жөнөтүүдө ката кетти", report_text

    @staticmethod
    async def test_telegram_connection(
        bot_token: str,
        chat_id: str,
        school_name: str = "№1 Орто Мектеп",
    ) -> Tuple[bool, Optional[str]]:
        """
        Sends a test verification message to ensure Bot Token and Chat ID are working.
        """
        text = (
            f"✅ <b>Telegram Бот ийгиликтүү туташты!</b>\n\n"
            f"🏫 <b>Мектеп:</b> {school_name}\n"
            f"🔔 Бул канал/тайпа аркылуу мугалимдердин күндөлүк катышуу жана кечигүү отчеттору жөнөтүлүп турат.\n\n"
            f"⏱ <i>Текшерилген убакыт: {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}</i>"
        )
        return await TelegramService.send_message(bot_token, chat_id, text)

    @staticmethod
    async def check_and_send_scheduled_reports(db: AsyncSession) -> int:
        """
        Checks all active schools with telegram_enabled == True.
        If local school time is >= school.telegram_report_time and report hasn't been sent today,
        generates and sends the daily report and updates last_telegram_report_sent_date.
        """
        stmt = select(School).where(
            School.is_active == True,  # noqa: E712
            School.telegram_enabled == True,  # noqa: E712
        )
        result = await db.execute(stmt)
        schools = result.scalars().all()

        sent_count = 0
        for school in schools:
            bot_token = school.telegram_bot_token or getattr(settings, "TELEGRAM_BOT_TOKEN", None)
            chat_id = school.telegram_chat_id or getattr(settings, "TELEGRAM_CHAT_ID", None)

            if not bot_token or not chat_id:
                continue

            local_dt = current_time_in_school_timezone(school.timezone)
            local_date = today_date_in_school_timezone(school.timezone)
            report_time = school.telegram_report_time

            # Default to 17:30 if not specified
            if not report_time:
                from datetime import time as dt_time
                report_time = dt_time(17, 30)

            # Check if current time has reached or passed scheduled report time
            if local_dt.time() >= report_time:
                # Check if already sent today
                if school.last_telegram_report_sent_date == local_date:
                    continue

                logger.info(
                    f"[Automated Telegram Report] Triggering scheduled report for {school.name} "
                    f"(target_date={local_date}, scheduled_time={report_time}, chat_id={chat_id})"
                )

                try:
                    success, msg, _ = await TelegramService.send_daily_report(
                        db=db,
                        school_id=school.id,
                        target_date=local_date,
                    )

                    if success:
                        school.last_telegram_report_sent_date = local_date
                        await db.commit()
                        sent_count += 1
                        logger.info(f"[Automated Telegram Report] Successfully delivered report for {school.name}")
                    else:
                        logger.warning(f"[Automated Telegram Report] Delivery failed for {school.name}: {msg}")
                except Exception as ex:
                    logger.error(f"[Automated Telegram Report] Error sending report for {school.name}: {ex}", exc_info=True)

        return sent_count

    @staticmethod
    async def start_scheduler():
        """
        Background worker task that runs every 60 seconds to check and trigger automated daily reports.
        """
        import asyncio
        from app.db.session import AsyncSessionLocal

        logger.info("Telegram Automated Daily Report background worker started.")
        while True:
            try:
                async with AsyncSessionLocal() as session:
                    await TelegramService.check_and_send_scheduled_reports(session)
            except asyncio.CancelledError:
                logger.info("Telegram background scheduler stopped.")
                break
            except Exception as e:
                logger.error(f"Telegram background scheduler error: {e}", exc_info=True)

            await asyncio.sleep(60)
