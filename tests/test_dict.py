import pytest
from starkware.starknet.testing.starknet import Starknet
import asyncio
import logging

LOGGER = logging.getLogger(__name__)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope="module")
async def starknet():
    starknet = await Starknet.empty()
    return starknet


@pytest.mark.asyncio
async def test(starknet):
    # Deploy contract
    contract = await starknet.deploy(source='contracts/test/test_utils.cairo')
    LOGGER.info(f'> Deployed test_utils.cairo.')

    LOGGER.info('> First test: pass')
    await contract.test_check_uniqueness(
        [(1, 0), (2, 0), (1, 1), (2, 1), (4, 0),
         (4, 1), (3, 3), (4, 3), (5, 3), (1, 5)],
        [(3, 0), (3, 1), (4, 2), (5, 4), (6, 4),
         (2, 5), (3, 5), (4, 5), (5, 5), (6, 5)],
    ).call()

    LOGGER.info('> Second test: overlapping outputs')
    with pytest.raises(Exception) as e_info:
        await contract.test_check_uniqueness(
            [(1, 0), (2, 0), (1, 1), (2, 1), (4, 0),
             (4, 1), (3, 3), (4, 3), (5, 3), (1, 5)],
            [(3, 0), (3, 1), (4, 2), (5, 4), (6, 4),
             (2, 5), (3, 5), (4, 5), (5, 5), (5, 5)],
        ).call()
    LOGGER.info(f'> Execution failed with {e_info}')

    LOGGER.info('> Third test: overlapping inputs')
    with pytest.raises(Exception) as e_info:
        await contract.test_check_uniqueness(
            [(1, 0), (2, 0), (1, 1), (1, 1), (4, 0),
             (4, 1), (3, 3), (4, 3), (5, 3), (1, 5)],
            [(3, 0), (3, 1), (4, 2), (5, 4), (6, 4),
             (2, 5), (3, 5), (4, 5), (5, 5), (6, 5)],
        ).call()
    LOGGER.info(f'> Execution failed with {e_info}')

    LOGGER.info('> Fourth test: overlapping input / output')
    with pytest.raises(Exception) as e_info:
        await contract.test_check_uniqueness(
            [(1, 0), (2, 0), (1, 1), (2, 1), (4, 0),
             (4, 1), (3, 3), (4, 3), (5, 3), (1, 5)],
            [(3, 0), (2, 1), (4, 2), (5, 4), (6, 4),
             (2, 5), (3, 5), (4, 5), (5, 5), (6, 5)],
        ).call()
    LOGGER.info(f'> Execution failed with {e_info}')
