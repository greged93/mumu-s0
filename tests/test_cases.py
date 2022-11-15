from re import M
import json
import pytest
from starkware.starknet.testing.starknet import Starknet
import asyncio
import logging

LOGGER = logging.getLogger(__name__)


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

    i = ["Z,D,X,A,Z,D,D,X,A,A",
        "_,Z,S,D,H,A,W,G,S,D,D,H,A,A,W",
        "G,D,H,A,S,G,D,H,A,W",
        "G,S,X,W,G,S,D,X,A,W",
        "G,S,S,S,X,W,W,W",
        "G,A,A,A,A,S,X,W,D,D,D,D",
        "G,S,S,D,X,A,W,W",
        "G,S,S,S,D,H,A,W,W,W",]

    instructions_length = [len(x)//2 + 1 for x in i]
    instructions = sum(list(map(adjust_from_string, i)), [])

    # # Loop the baby
    ret = await contract.simulator(
        [(0, 0, 0, (0, 0)), (1, 0, 0, (0, 0)), (2, 0, 0, (3, 0)), (3, 0, 0, (4, 2)),
         (4, 0, 0, (3, 0)), (5, 0, 0, (5, 4)), (6, 0, 0, (6, 5)), (7, 0, 0, (6, 4))],
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

    assert frames['static cost'] == 3950, f'static cost error, expected 3950, got {frames["static cost"]}'
    assert frames['delivered'] == 1, f'delivered error, expected 1, got {frames["delivered"]}'
    assert frames['average latency']/1000000 == 46, f'average latency error, expected 46, got {frames["average latency"]/1000000}'
    assert frames['average dynamic cost']/1000000 == 3574, f'average dynamic cost error, expected 3574, got {frames["average dynamic cost"]/1000000}'

    i = ["G,D,H,A,G,D,D,H,A,A",
        "G,S,D,H,A,W,G,S,D,D,H,A,A,W",
        "G,S,D,D,H,A,A,W,G,S,D,H,A,W",
        "G,D,H,A,G,D,H,A,S,G,S,H,W,W",
        "G,D,H,S,G,A,A,A,H,D,D,W,G,D,H,S,G,A,A,H,D,W",
        "G,S,X,D,W,G,W,W,H,S,S,S,Z,W,W,W,A,H,S,S,S,S,D,Z,D,X,W,A,A,W",
        "G,S,X,D,W,G,S,A,X,D,W,W,G,S,S,A,X,W"]

    instructions_length = [len(x)//2 + 1 for x in i]
    instructions = sum(list(map(adjust_from_string, i)), [])

    # # Loop the baby
    ret = await contract.simulator(
        [(0, 0, 0, (0, 0)), (1, 0, 0, (0, 0)), (2, 0, 0, (0, 0)), (3, 0, 0, (3, 0)),
         (4, 0, 0, (3, 1)), (5, 0, 0, (1, 3)), (6, 0, 0, (0, 6))],
        instructions_length,
        instructions,
        [(1, 0), (2, 0), (1, 1), (2, 1), (4, 0),
         (4, 1), (3, 2), (2, 2), (1, 2), (1, 4)],
        [(3, 0), (3, 1), (4, 2), (1, 3), (2, 3),
         (2, 4), (2, 5), (1, 5), (1, 6), (0, 6)],
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

    assert frames['static cost'] == 3800, f'static cost error, expected 3800, got {frames["static cost"]}'
    assert frames['delivered'] == 2, f'delivered error, expected 2, got {frames["delivered"]}'
    assert frames['average latency']/1000000 == 32, f'average latency error, expected 32, got {frames["average latency"]/1000000}'
    assert frames['average dynamic cost']/1000000 == 3224, f'average dynamic cost error, expected 3224, got {frames["average dynamic cost"]/1000000}'