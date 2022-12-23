import pytest
from starkware.starknet.testing.starknet import Starknet
import asyncio
import logging

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
    contract = await starknet.deploy(source="contracts/test/test_utils.cairo")
    LOGGER.info(f"> Deployed test_utils.cairo.")

    LOGGER.info("> First test check uniqueness: pass")
    await contract.test_check_uniqueness(
        [
            (1, 0),
            (2, 0),
            (1, 1),
            (2, 1),
            (4, 0),
            (4, 1),
            (3, 3),
            (4, 3),
            (5, 3),
            (1, 5),
        ],
        [
            (3, 0),
            (3, 1),
            (4, 2),
            (5, 4),
            (6, 4),
            (2, 5),
            (3, 5),
            (4, 5),
            (5, 5),
            (6, 5),
        ],
    ).call()

    LOGGER.info("> Second test check uniqueness: overlapping outputs")
    with pytest.raises(Exception) as e_info:
        await contract.test_check_uniqueness(
            [
                (1, 0),
                (2, 0),
                (1, 1),
                (2, 1),
                (4, 0),
                (4, 1),
                (3, 3),
                (4, 3),
                (5, 3),
                (1, 5),
            ],
            [
                (3, 0),
                (3, 1),
                (4, 2),
                (5, 4),
                (6, 4),
                (2, 5),
                (3, 5),
                (4, 5),
                (5, 5),
                (5, 5),
            ],
        ).call()
        assert e_info.message == "Error message: overlapping operators"

    LOGGER.info("> Third test check uniqueness: overlapping inputs")
    with pytest.raises(Exception) as e_info:
        await contract.test_check_uniqueness(
            [
                (1, 0),
                (2, 0),
                (1, 1),
                (1, 1),
                (4, 0),
                (4, 1),
                (3, 3),
                (4, 3),
                (5, 3),
                (1, 5),
            ],
            [
                (3, 0),
                (3, 1),
                (4, 2),
                (5, 4),
                (6, 4),
                (2, 5),
                (3, 5),
                (4, 5),
                (5, 5),
                (6, 5),
            ],
        ).call()
        assert e_info.message == "Error message: overlapping operators"

    LOGGER.info("> Fourth test check uniqueness: overlapping input / output")
    with pytest.raises(Exception) as e_info:
        await contract.test_check_uniqueness(
            [
                (1, 0),
                (2, 0),
                (1, 1),
                (2, 1),
                (4, 0),
                (4, 1),
                (3, 3),
                (4, 3),
                (5, 3),
                (1, 5),
            ],
            [
                (3, 0),
                (2, 1),
                (4, 2),
                (5, 4),
                (6, 4),
                (2, 5),
                (3, 5),
                (4, 5),
                (5, 5),
                (6, 5),
            ],
        ).call()
        assert e_info.message == "Error message: overlapping operators"

    LOGGER.info("> First test verify operators: pass")
    await contract.test_verify_valid_operators(
        [(0, 0), (7, 0), (0, 7), (7, 7)],
        [0, 0, 1, 2, 3],
        [
            (1, 0),
            (2, 0),
            (1, 1),
            (2, 1),
            (4, 0),
            (4, 1),
            (3, 3),
            (4, 3),
            (5, 3),
            (1, 5),
        ],
        [
            (3, 0),
            (3, 1),
            (4, 2),
            (5, 4),
            (6, 4),
            (2, 5),
            (3, 5),
            (4, 5),
            (5, 5),
            (6, 5),
        ],
        7,
    ).call()

    LOGGER.info("> Second test verify operators: overlapping piping")
    with pytest.raises(Exception) as e_info:
        await contract.test_verify_valid_operators(
            [(0, 0), (7, 0), (0, 7), (7, 7)],
            [0, 0, 1, 2, 3],
            [
                (7, 0),
                (7, 1),
                (1, 1),
                (2, 1),
                (4, 0),
                (4, 1),
                (3, 3),
                (4, 3),
                (5, 3),
                (1, 5),
            ],
            [
                (7, 2),
                (3, 1),
                (4, 2),
                (5, 4),
                (6, 4),
                (2, 5),
                (3, 5),
                (4, 5),
                (5, 5),
                (6, 5),
            ],
            7,
        ).call()
        assert e_info.message == "Error message: overlapping piping"

    LOGGER.info("> Third test verify operators: out of bound")
    with pytest.raises(Exception) as e_info:
        await contract.test_verify_valid_operators(
            [(0, 0), (7, 0), (0, 7), (7, 7)],
            [0, 0, 1, 2, 3],
            [
                (1, 0),
                (2, 0),
                (1, 1),
                (2, 1),
                (4, 0),
                (4, 1),
                (3, 3),
                (4, 8),
                (5, 3),
                (1, 5),
            ],
            [
                (3, 0),
                (3, 1),
                (4, 2),
                (5, 4),
                (6, 4),
                (2, 5),
                (3, 5),
                (4, 5),
                (5, 5),
                (6, 5),
            ],
            7,
        ).call()
        assert e_info.message == "Error message: operator not within bounds"

    LOGGER.info("> Fourth test verify operators: continuity error")
    with pytest.raises(Exception) as e_info:
        await contract.test_verify_valid_operators(
            [(0, 0), (7, 0), (0, 7), (7, 7)],
            [0, 0, 1, 2, 3],
            [
                (1, 0),
                (2, 1),
                (1, 1),
                (2, 1),
                (4, 0),
                (4, 1),
                (3, 3),
                (4, 3),
                (5, 3),
                (1, 5),
            ],
            [
                (3, 0),
                (3, 1),
                (4, 2),
                (5, 4),
                (6, 4),
                (2, 5),
                (3, 5),
                (4, 5),
                (5, 5),
                (6, 5),
            ],
            7,
        ).call()
        assert e_info.message == "Error message: operator continuity error"
