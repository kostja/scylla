#
# Copyright (C) 2022-present ScyllaDB
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#
"""
Test functionality on the cluster with different values of the --smp parameter on the nodes.
"""
import logging
import time
from test.pylib.manager_client import ManagerClient
from test.pylib.random_tables import RandomTables
from test.pylib.util import unique_name
from test.topology.util import wait_for_token_ring_and_group0_consistency
import pytest

logger = logging.getLogger(__name__)

# Checks a cluster boot/operations in multi-dc environment
@pytest.mark.asyncio
async def test_multidc(request: pytest.FixtureRequest, manager: ManagerClient) -> None:

    logger.info(f'Creating a new node')
    for i in range (30):
        s_info = await manager.server_add(config={'snitch': 'GossipingPropertyFileSnitch'},
         property_file={
             'dc': 'dc{}'.format(i),
             'rack': 'myrack'
         })
    random_tables = RandomTables(request.node.name, manager, unique_name(), 3)
    logger.info(s_info)
    logger.info(f'Creating new tables')
    await random_tables.add_tables(ntables=3, ncolumns=3)
    await random_tables.verify_schema()
