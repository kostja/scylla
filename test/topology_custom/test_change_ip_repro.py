import asyncio
import logging
import time
import pytest

from test.pylib.manager_client import ManagerClient
from test.pylib.util import read_barrier, wait_for_cql_and_get_hosts


logger = logging.getLogger(__name__)


@pytest.mark.asyncio
async def test_change_ip_repro(manager: ManagerClient) -> None:
    s1 = await manager.server_add()
    s2 = await manager.server_add()
    logger.info(f"Stopping {s2}")
    await manager.server_stop_gracefully(s2.server_id)
    await manager.server_change_ip(s2.server_id)
    logger.info(f"Starting {s2}")
    await manager.server_start(s2.server_id)
    logger.info(f"Sleep before read barrier")
    await asyncio.sleep(6)
    cql = manager.get_cql()
    logger.info(f"Wait for cql")
    h1 = (await wait_for_cql_and_get_hosts(cql, [s1], time.time() + 60))[0]
    logger.info(f"Read barrier")
    await read_barrier(cql, h1)
    logger.info(f"Done")
