from re import M
import pytest
from starkware.starknet.testing.starknet import Starknet
import asyncio
import logging

LOGGER = logging.getLogger(__name__)

PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481
PRIME_HALF = PRIME//2


def adjust_from_string(instruction):
    i = []
    for s in instruction:
        if s == "W":
            i.append(0)
        if s == "A":
            i.append(1)
        if s == "S":
            i.append(2)
        if s == "D":
            i.append(3)
        if s == "Z":
            i.append(4)
        if s == "X":
            i.append(5)
        if s == "_":
            i.append(6)
    return i


def get_object_events(events, size):
    j = 0
    obj = ()
    for e in events:
        if len(obj) == size:
            LOGGER.info(obj)
            obj = ()
        if e.value == 1000:
            LOGGER.info(f'NEW FRAME {j}')
            j += 1
            continue
        obj += (e.value,)


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
    contract = await starknet.deploy(source='contracts/simulator.cairo')
    LOGGER.info(f'> Deployed simulator.cairo.')

    i = ["Z,D,X,A,_,_,_,_,_,_,_",
         "_,Z,D,D,X,A,A,_,_,_,_",
         "_,_,Z,S,D,X,A,W,_,_,_",
         "_,_,_,Z,S,D,D,X,A,A,W",
         "Z,D,X,A",
         "Z,D,X,A",
         "Z,S,X,W,Z,S,D,X,A,W",
         "Z,S,S,A,X,D,W,W",
         "Z,S,S,D,X,A,W,W"]

    instructions_length = [len(x)//2 + 1 for x in i]
    instructions = sum(list(map(adjust_from_string, i)), [])
    N = 90

    # # Loop the baby
    ret = await contract.simulator(
        N,
        7,
        [(0, 0, 0, (0, 0)), (1, 0, 0, (0, 0)), (2, 0, 0, (0, 0)), (3, 0, 0, (0, 0)),
         (4, 0, 0, (3, 0)), (5, 0, 0, (3, 1)), (6, 0, 0, (4, 2)), (7, 0, 0, (4, 1)), (8, 0, 0, (5, 4))],
        [],
        instructions_length,
        instructions,
        [(0, 0, (0, 0))],
        [(0, (6, 6))],
        [(1, 0), (2, 0), (1, 1), (2, 1), (4, 0), (4, 1), (3, 3), (4, 3), (5, 3)],
        [(3, 0), (3, 1), (4, 2), (5, 4), (6, 4)],
        [0, 0, 1, 2],
    ).call()

    events = ret.main_call_events

    # 5 for mechs, 6 for atoms and 9 for instructions
    get_object_events(events, 6)

    LOGGER.info(
        f'> Simulation of {N} frames took execution_resources = {ret.call_info.execution_resources}')


