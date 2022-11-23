from re import M
import pytest
from starkware.starknet.testing.starknet import Starknet
import asyncio
import logging
from utils import import_json

LOGGER = logging.getLogger(__name__)


@pytest.fixture(scope="module")
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope="module")
async def starknet():
    starknet = await Starknet.empty()
    return starknet


@pytest.mark.asyncio
async def test(starknet):

    # Deploy contract
    contract = await starknet.deploy(source="contracts/simulator/simulator.cairo")
    LOGGER.info(f"> Deployed simulator.cairo.")

    await contract.simulator(
        [
            (0, 0, 0, (0, 0)),
            (1, 0, 0, (0, 0)),
            (2, 0, 0, (0, 0)),
            (3, 0, 0, (0, 0)),
            (4, 0, 0, (0, 0)),
            (5, 0, 0, (0, 0)),
            (6, 0, 0, (0, 0)),
            (7, 0, 0, (0, 0)),
            (8, 0, 0, (0, 0)),
            (9, 0, 0, (0, 0)),
            (10, 0, 0, (0, 0)),
            (11, 0, 0, (0, 0)),
            (12, 0, 0, (0, 0)),
            (13, 0, 0, (0, 0)),
            (14, 0, 0, (0, 0)),
            (15, 0, 0, (0, 0)),
            (16, 0, 0, (0, 0)),
            (17, 0, 0, (0, 0)),
            (18, 0, 0, (0, 0)),
            (19, 0, 0, (0, 0)),
            (20, 0, 0, (0, 0)),
            (21, 0, 0, (0, 0)),
            (22, 0, 0, (0, 0)),
            (23, 0, 0, (0, 0)),
            (24, 0, 0, (0, 0)),
        ],
        [],
        [],
        [],
        [],
        [],
    ).call()

    with pytest.raises(Exception) as e_info:
        await contract.simulator(
            [
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
                (0, 0, 0, (0, 0)),
            ],
            [],
            [],
            [],
            [],
            [],
        ).call()
        assert e_info.message == "Error message: mech length limited to 25"
