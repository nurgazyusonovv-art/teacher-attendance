import importlib.util
from pathlib import Path
from alembic.migration import MigrationContext
from alembic.operations import Operations
import sqlalchemy as sa


def test_subject_migration_adopts_existing_schema_without_deleting_rows():
    path = Path(__file__).parents[1] / "alembic/versions/2026_08_26_1635-f7129841abcd_add_subject_and_lesson_delays.py"
    spec = importlib.util.spec_from_file_location("legacy_migration", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        connection.execute(sa.text("CREATE TABLE teachers (id VARCHAR(36) PRIMARY KEY, subject VARCHAR(100))"))
        connection.execute(sa.text("INSERT INTO teachers VALUES ('t', 'Математика')"))
        connection.execute(sa.text("CREATE TABLE schools (id VARCHAR(36) PRIMARY KEY)"))
        connection.execute(sa.text("CREATE TABLE users (id VARCHAR(36) PRIMARY KEY)"))
        with Operations.context(MigrationContext.configure(connection)):
            module.upgrade()
            module.upgrade()
        assert connection.execute(sa.text("SELECT subject FROM teachers WHERE id='t'")).scalar_one() == "Математика"
        assert sa.inspect(connection).has_table("lesson_delays")
    engine.dispose()
