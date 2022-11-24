from re import M
import pytest
from starkware.starknet.testing.starknet import Starknet
import asyncio
import logging
from utils import import_json, DESCRIPTIONS

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

    static_costs = [4250, 6000]
    delivereds = [4, 2]
    latencies = [36.5, 38]
    dynamic_costs = [4089.25, 3639]

    ### Run the test cases ###
    for i in range(2):
        LOGGER.info(f"> Importing file test{i}_description.json")
        (
            mechs,
            instructions_length,
            instructions,
            inputs,
            outputs,
            types,
        ) = import_json(f"./tests/test-cases/test{i}_description.json")

        #### Loop the baby ###
        ret = await contract.simulator(
            mechs, instructions_length, instructions, inputs, outputs, types
        ).call()

        events = ret.main_call_events

        LOGGER.info(
            f"> Simulation of 150 frames took execution_resources = {ret.call_info.execution_resources}"
        )

        frames = {
            "solver": events[0].solver,
            "mechs": events[0].mechs,
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

        for mech in frames["mechs"]:
            x: int = mech.description
            bytes_length = (x.bit_length() + 7) // 8
            dec = int.to_bytes(x, bytes_length, "big").decode("utf8")
            assert (
                dec in DESCRIPTIONS
            ), f"description error, expected one of {DESCRIPTIONS}, got {dec}"

        assert (
            frames["static cost"] == static_costs[i]
        ), f'static cost error, expected {static_costs[i]}, got {frames["static cost"]}'
        assert (
            frames["delivered"] == delivereds[i]
        ), f'delivered error, expected {delivereds[i]}, got {frames["delivered"]}'
        assert (
            frames["average latency"] / 1000000 == latencies[i]
        ), f'average latency error, expected {latencies[i]}, got {frames["average latency"]/1000000}'
        assert (
            frames["average dynamic cost"] / 1000000 == dynamic_costs[i]
        ), f'average dynamic cost error, expected {dynamic_costs[i]}, got {frames["average dynamic cost"]/1000000}'
