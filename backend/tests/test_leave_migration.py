import importlib.util
from pathlib import Path
from alembic.migration import MigrationContext
from alembic.operations import Operations
import sqlalchemy as sa


def test_leave_migration_roundtrip_keeps_parent_records():
    path = Path(__file__).parents[1] / 'alembic/versions/2026_09_09_0004_leave_requests.py'
    spec = importlib.util.spec_from_file_location('leave_migration', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    engine = sa.create_engine('sqlite://')
    with engine.begin() as connection:
        for table in ('schools', 'teachers', 'users'):
            connection.execute(sa.text(f'CREATE TABLE {table} (id VARCHAR(36) PRIMARY KEY)'))
            connection.execute(sa.text(f"INSERT INTO {table} VALUES ('existing')"))
        with Operations.context(MigrationContext.configure(connection)):
            module.upgrade()
            assert sa.inspect(connection).has_table('leave_requests')
            module.downgrade()
            module.upgrade()
        assert connection.execute(sa.text('SELECT COUNT(*) FROM teachers')).scalar_one() == 1
        unique = sa.inspect(connection).get_unique_constraints('leave_requests')
        assert any(item['name'] == 'uq_leave_teacher_date' for item in unique)
    engine.dispose()
