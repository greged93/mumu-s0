from re import M
import json
import pytest
from starkware.starknet.testing.starknet import Starknet
import asyncio
import logging

LOGGER = logging.getLogger(__name__)


# TODO update based on new implementation for G and H
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
        if s == "G":
            i.append(6)
        if s == "H":
            i.append(7)
        if s == "_":
            i.append(8)
    return i


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
    contract = await starknet.deploy(source='contracts/simulator/simulator.cairo')
    LOGGER.info(f'> Deployed simulator.cairo.')

    # base
    # i = ["Z,D,X,A,_,_,_,_,_,_,_",
    #      "_,Z,D,D,X,A,A,_,_,_,_",
    #      "_,_,Z,S,D,X,A,W,_,_,_",
    #      "_,_,_,Z,S,D,D,X,A,A,W",
    #      "Z,D,X,A",
    #      "Z,D,X,A",
    #      "Z,S,X,W,Z,S,D,X,A,W",
    #      "Z,S,S,A,X,D,W,W",
    #      "Z,A,A,A,A,S,X,W,D,D,D,D",
    #      "_,_,_,_,_,_,_,_,Z,S,X,W"]
    # case 1
    # i = ["Z,D,X,A,Z,D,D,X,A,A",
    #      "_,Z,S,D,H,A,W,G,S,D,D,H,A,A,W",
    #      "G,D,H,A,S,G,D,H,A,W",
    #      "G,S,X,W,G,S,D,X,A,W",
    #      "G,S,S,S,X,W,W,W",
    #      "G,A,A,A,A,S,X,W,D,D,D,D",
    #      "G,S,X,W"]
    # case 2
    # i = ["Z,D,X,A,Z,D,D,X,A,A",
    #      "_,Z,S,D,H,A,W,G,S,D,D,H,A,A,W",
    #      "G,D,H,A,S,G,D,H,A,W",
    #      "G,S,X,W,G,S,D,X,A,W",
    #      "G,S,S,S,X,W,W,W",
    #      "G,A,A,A,A,S,X,W,D,D,D,D",
    #      "G,S,X,W",
    #      "G,S,S,H,W,W"]
    # case 3
    i = ["Z,D,X,A,Z,D,D,X,A,A",
         "_,Z,S,D,H,A,W,G,S,D,D,H,A,A,W",
         "G,D,H,A,S,G,D,H,A,W",
         "G,S,X,W,G,S,D,X,A,W",
         "G,S,S,S,X,W,W,W",
         "G,A,A,A,A,S,X,W,D,D,D,D",
         "G,S,X,W",
         "G,S,S,H,W,W",
         "G,S,D,D,D,D,X,A,A,A,W,Z,S,D,D,D,X,A,A,W,Z,S,D,D,X,A,W,Z,S,D,X,A,A,A,A,W"]

    instructions_length = [len(x)//2 + 1 for x in i]
    instructions = sum(list(map(adjust_from_string, i)), [])

    # # Loop the baby
    ret = await contract.simulator(
        # base
        # [(0, 0, 0, (0, 0)), (1, 0, 0, (0, 0)), (2, 0, 0, (0, 0)), (3, 0, 0, (0, 0)),
        #  (4, 0, 0, (3, 0)), (5, 0, 0, (3, 1)), (6, 0, 0, (4, 2)), (7, 0, 0, (4, 1)),
        #  (8, 0, 0, (5, 4)), (9, 0, 0, (6, 5))],
        # case 1
        # [(0, 0, 0, (0, 0)), (1, 0, 0, (0, 0)), (2, 0, 0, (3, 0)), (3, 0, 0, (4, 2)),
        #  (4, 0, 0, (3, 0)), (5, 0, 0, (5, 4)), (6, 0, 0, (6, 5))],
        # case 2
        # [(0, 0, 0, (0, 0)), (1, 0, 0, (0, 0)), (2, 0, 0, (3, 0)), (3, 0, 0, (4, 2)),
        #  (4, 0, 0, (3, 0)), (5, 0, 0, (5, 4)), (6, 0, 0, (6, 5)), (7, 0, 0, (6, 4))],
        # case 3
        [(0, 0, 0, (0, 0)), (1, 0, 0, (0, 0)), (2, 0, 0, (3, 0)), (3, 0, 0, (4, 2)),
         (4, 0, 0, (3, 0)), (5, 0, 0, (5, 4)), (6, 0, 0, (6, 5)), (7, 0, 0, (6, 4)),
         (8, 0, 0, (2, 5))],
        instructions_length,
        instructions,
        [(1, 0), (2, 0), (1, 1), (2, 1), (4, 0),
         (4, 1), (3, 3), (4, 3), (5, 3), (1, 5)],
        [(3, 0), (3, 1), (4, 2), (5, 4), (6, 4),
         (2, 5), (3, 5), (4, 5), (5, 5), (6, 5)],
        [0, 0, 1, 2, 3],
    ).call()

    events = ret.main_call_events

    LOGGER.info(
        f'> Simulation of 80 frames took execution_resources = {ret.call_info.execution_resources}')

    frames = {
        'solver': events[0].solver,
        'instructions length per mech': events[0].instructions_sets,
        'instructions': events[0].instructions,
        'operators input': events[0].operators_inputs,
        'operators ouput': events[0].operators_outputs,
        'operators type': events[0].operators_type,
        'static cost': events[0].static_cost,
        'delivered': events[-1].delivered,
        'average latency': events[-1].latency,
        'average dynamic cost': events[-1].dynamic_cost,
    }

    #
    # Export record
    #
    short = False
    path = 'artifacts/test_simulator.json' if not short else 'artifacts/test_simulator_short.json'
    json_string = json.dumps(frames)
    with open(path, 'w') as f:
        json.dump(json_string, f)
    LOGGER.info(f'> Frame records exported to {path}.')
