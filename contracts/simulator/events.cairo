%lang starknet

from contracts.simulator.mechs import InputMechState
from contracts.simulator.atoms import AtomState, AtomFaucetState, AtomSinkState
from contracts.simulator.grid import Grid

//
// Standard for events generation of Frame
//

@event
func new_simulation(
    solver: felt,
    music_title: felt,
    mechs_len: felt,
    mechs: InputMechState*,
    instructions_sets_len: felt,
    instructions_sets: felt*,
    instructions_len: felt,
    instructions: felt*,
    operators_inputs_len: felt,
    operators_inputs: Grid*,
    operators_outputs_len: felt,
    operators_outputs: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
    mech_volumes_len: felt,
    mech_volumes: felt*,
    faucets_len: felt,
    faucets: AtomFaucetState*,
    sinks_len: felt,
    sinks: AtomSinkState*,
    static_cost: felt,
) {
}

@event
func end_summary(delivered: felt, latency: felt, dynamic_cost: felt) {
}
