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

    ### Test case 1 ###

    (mechs, instructions_length, instructions, inputs, outputs, types) = import_json(
        "./tests/test-cases/test1.json"
    )

    # # Loop the baby
    ret = await contract.simulator(
        mechs, instructions_length, instructions, inputs, outputs, types
    ).call()

    events = ret.main_call_events

    LOGGER.info(
        f"> Simulation of 100 frames took execution_resources = {ret.call_info.execution_resources}"
    )

    frames = {
        "solver": events[0].solver,
        "instructions length per mech": events[0].instructions_sets,
        "instructions": events[0].instructions,
        "operators input": events[0].operators_inputs,
        "operators ouput": events[0].operators_outputs,
        "operators type": events[0].operators_type,
        "static cost": events[0].static_cost,
        "delivered": events[-1].delivered,
        "average latency": events[-1].latency,
        "average dynamic cost": events[-1].dynamic_cost,
    }

    assert (
        frames["static cost"] == 3950
    ), f'static cost error, expected 3950, got {frames["static cost"]}'
    assert (
        frames["delivered"] == 1
    ), f'delivered error, expected 1, got {frames["delivered"]}'
    assert (
        frames["average latency"] / 1000000 == 46
    ), f'average latency error, expected 46, got {frames["average latency"]/1000000}'
    assert (
        frames["average dynamic cost"] / 1000000 == 3574
    ), f'average dynamic cost error, expected 3574, got {frames["average dynamic cost"]/1000000}'

    ### Test case 2 ###

    (mechs, instructions_length, instructions, inputs, outputs, types) = import_json(
        "./tests/test-cases/test2.json"
    )

    # # Loop the baby
    ret = await contract.simulator(
        mechs, instructions_length, instructions, inputs, outputs, types
    ).call()

    events = ret.main_call_events

    LOGGER.info(
        f"> Simulation of 100 frames took execution_resources = {ret.call_info.execution_resources}"
    )

    frames = {
        "solver": events[0].solver,
        "instructions length per mech": events[0].instructions_sets,
        "instructions": events[0].instructions,
        "operators input": events[0].operators_inputs,
        "operators ouput": events[0].operators_outputs,
        "operators type": events[0].operators_type,
        "static cost": events[0].static_cost,
        "delivered": events[-1].delivered,
        "average latency": events[-1].latency,
        "average dynamic cost": events[-1].dynamic_cost,
    }

    assert (
        frames["static cost"] == 3800
    ), f'static cost error, expected 3800, got {frames["static cost"]}'
    assert (
        frames["delivered"] == 2
    ), f'delivered error, expected 2, got {frames["delivered"]}'
    assert (
        frames["average latency"] / 1000000 == 32
    ), f'average latency error, expected 32, got {frames["average latency"]/1000000}'
    assert (
        frames["average dynamic cost"] / 1000000 == 3224
    ), f'average dynamic cost error, expected 3224, got {frames["average dynamic cost"]/1000000}'

    ### Test case 3 ###

    (mechs, instructions_length, instructions, inputs, outputs, types) = import_json(
        "./tests/test-cases/test3.json"
    )

    # # Loop the baby
    ret = await contract.simulator(
        mechs, instructions_length, instructions, inputs, outputs, types
    ).call()

    events = ret.main_call_events

    LOGGER.info(
        f"> Simulation of 100 frames took execution_resources = {ret.call_info.execution_resources}"
    )

    frames = {
        "solver": events[0].solver,
        "instructions length per mech": events[0].instructions_sets,
        "instructions": events[0].instructions,
        "operators input": events[0].operators_inputs,
        "operators ouput": events[0].operators_outputs,
        "operators type": events[0].operators_type,
        "static cost": events[0].static_cost,
        "delivered": events[-1].delivered,
        "average latency": events[-1].latency,
        "average dynamic cost": events[-1].dynamic_cost,
    }

    assert (
        frames["static cost"] == 7000
    ), f'static cost error, expected 7000, got {frames["static cost"]}'
    assert (
        frames["delivered"] == 5
    ), f'delivered error, expected 2, got {frames["delivered"]}'
    assert (
        frames["average latency"] / 1000000 == 20
    ), f'average latency error, expected 20, got {frames["average latency"]/1000000}'
    assert (
        frames["average dynamic cost"] / 1000000 == 3780.8
    ), f'average dynamic cost error, expected 3780.8, got {frames["average dynamic cost"]/1000000}'
