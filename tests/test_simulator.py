from re import M
import pytest
import json
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.business_logic.state.state import BlockInfo
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


def get_mechs(events, mechs_size):
    for i in range(len(events)//mechs_size):
        mech = (events[i*mechs_size].value, events[i*mechs_size + 1].value, events[i*mechs_size + 2].value,
                events[i*mechs_size + 3].value, events[i*mechs_size + 4].value)
        LOGGER.info(mech)


def get_atoms(events, atoms_size):
    for i in range(len(events)//atoms_size):
        atom = (events[i*atoms_size].value, events[i*atoms_size + 1].value, events[i*atoms_size + 2].value,
                events[i*atoms_size + 3].value, events[i*atoms_size + 4].value, events[i*atoms_size + 5].value)
        LOGGER.info(atom)


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

    # # Loop the baby
    ret = await contract.simulator(
        10,
        7,
        [(0, 0, 0, (0, 0)), (1, 0, 0, (0, 0)), (2, 0, 0, (0, 0)), (3, 0, 0, (0, 0)),
         (4, 0, 0, (3, 0)), (5, 0, 0, (3, 1)), (6, 0, 0, (4, 2)), (7, 0, 0, (4, 1)), (8, 0, 0, (5, 4))],
        [],
        instructions_length,
        instructions,
        [(0, 0, (0, 0))],
        [(0, (6, 6))],
        [(1, 0), (2, 0), (1, 1), (2, 1), (4, 0), (4, 1), (3, 3), (4, 3), (5, 3)],
        [(3, 0), (3, 1), (4, 2), (5, 4), (5, 5)],
        [0, 0, 1, 2],
    ).call()

    mechs_len = 9
    events = ret.main_call_events
    LOGGER.info(events)

    get_atoms(events, 6)
    # get_mechs(events, 5)

    # LOGGER.info(
    #     f'> Simulation of {N} frames took execution_resources = {ret.call_info.execution_resources}')

    # # Organize events into record dict
    # record = ret.main_call_events[0].arr
    # record = {
    #     'agent_0': [{
    #         'agent_state': r.agent_0.agent_state,
    #         'agent_action': r.agent_0.agent_action,
    #         'object_state': r.agent_0.object_state,
    #         'object_counter': r.agent_0.object_counter,
    #         'character_state': {
    #             'pos': [r.agent_0.character_state.pos.x, r.agent_0.character_state.pos.y],
    #             'vel_fp': [r.agent_0.character_state.vel_fp.x, r.agent_0.character_state.vel_fp.y],
    #             'acc_fp': [r.agent_0.character_state.acc_fp.x, r.agent_0.character_state.acc_fp.y],
    #             'dir': r.agent_0.character_state.dir,
    #             'int': r.agent_0.character_state.int,
    #         },
    #         'hitboxes': {
    #             'action': {
    #                 'origin': [r.agent_0.hitboxes.action.origin.x, r.agent_0.hitboxes.action.origin.y],
    #                 'dimension': [r.agent_0.hitboxes.action.dimension.x, r.agent_0.hitboxes.action.dimension.y]
    #             },
    #             'body': {
    #                 'origin': [r.agent_0.hitboxes.body.origin.x, r.agent_0.hitboxes.body.origin.y],
    #                 'dimension': [r.agent_0.hitboxes.body.dimension.x, r.agent_0.hitboxes.body.dimension.y]
    #             }
    #         },
    #         'stimiulus': r.agent_0.stimulus
    #     } for r in record],
    #     'agent_1': [{
    #         'agent_state': r.agent_1.agent_state,
    #         'agent_action': r.agent_1.agent_action,
    #         'object_state': r.agent_1.object_state,
    #         'object_counter': r.agent_1.object_counter,
    #         'character_state': {
    #             'pos': [r.agent_1.character_state.pos.x, r.agent_1.character_state.pos.y],
    #             'vel_fp': [adjust_from_felt(r.agent_1.character_state.vel_fp.x), adjust_from_felt(r.agent_1.character_state.vel_fp.y)],
    #             'acc_fp': [adjust_from_felt(r.agent_1.character_state.acc_fp.x), adjust_from_felt(r.agent_1.character_state.acc_fp.y)],
    #             'dir': r.agent_1.character_state.dir,
    #             'int': r.agent_1.character_state.int,
    #         },
    #         'hitboxes': {
    #             'action': {
    #                 'origin': [r.agent_1.hitboxes.action.origin.x, r.agent_1.hitboxes.action.origin.y],
    #                 'dimension': [r.agent_1.hitboxes.action.dimension.x, r.agent_1.hitboxes.action.dimension.y]
    #             },
    #             'body': {
    #                 'origin': [r.agent_1.hitboxes.body.origin.x, r.agent_1.hitboxes.body.origin.y],
    #                 'dimension': [r.agent_1.hitboxes.body.dimension.x, r.agent_1.hitboxes.body.dimension.y]
    #             }
    #         },
    #         'stimiulus': r.agent_1.stimulus
    #     } for r in record]
    # }

    # #
    # # Debug log
    # #
    # for i in [0, 1]:
    #     LOGGER.info(f'> Agent_{i} records:')
    #     for r in record[f'agent_{i}']:
    #         LOGGER.info(f"  .. {r}")
    #     LOGGER.info('')

    # #
    # # Export record
    # #
    # json_string = json.dumps(record)
    # path = 'artifacts/test_engine.json'
    # with open(path, 'w') as f:
    #     json.dump(json_string, f)
    # LOGGER.info(f'> Frame records exported to {path}.')
