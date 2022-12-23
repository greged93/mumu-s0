import pytest
from starkware.starknet.testing.starknet import Starknet
from random import randint
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

    static_costs = [4100, 3550, 6000]
    delivereds = [4, 41, 14]
    latencies = [32.5, 3.585365, 10.285714]
    dynamic_costs = [3608.75, 303.560975, 1388.285714]
    faucets = [[(0, 0, (0,0)), (1, 1, (5,0)), (2, 3, (6,6))],
               [(0, 0, (3,4)), (1, 1, (4,4)), (2, 4, (5,4))],
               [(0, 1, (4,3)), (1, 1, (4,4)), (2, 1, (4,5))]]
    sinks = [[(0, (9,0)), (1, (0,9)), (2, (9,9)), (3, (2, 0))],
             [(0, (3,5)), (1, (4,5)), (2, (5, 5))],
             [(0, (1,3)), (1, (1,5)), (2, (7, 3)), (3, (7, 5))]]

    ### Run the test cases ###
    for i in range(3):
        LOGGER.info(f"> Importing file test{i}_daw.json")
        (
            mechs,
            instructions_length,
            instructions,
            inputs,
            outputs,
            types,
        ) = import_json(f"./tests/test-cases/test{i}_daw.json")
        mech_volumes = [randint(0,100) for i in range(len(mechs))]

        #### Loop the baby ###
        ret = await contract.simulator(
            123, 
            mechs, 
            instructions_length, 
            instructions, 
            inputs, 
            outputs, 
            types, 
            mech_volumes,
            faucets[i], 
            sinks[i]
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
            "volumes": events[0].mech_volumes,
            "faucets": events[0].faucets,
            "sinks": events[0].sinks,
            "static cost": events[0].static_cost,
            "delivered": events[-1].delivered,
            "average latency": events[-1].latency,
            "average dynamic cost": events[-1].dynamic_cost,
        }


        assert faucets[i] == frames["faucets"], f'faucets error, expected {faucets[i]}, got {frames["faucets"]}'
        assert sinks[i] == frames["sinks"], f'sinks error, expected {sinks[i]}, got {frames["sinks"]}'

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
