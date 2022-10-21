%lang starknet

from starkware.cairo.common.alloc import alloc

from contracts.constants import (
    ns_mech_type,
    ns_operator_type,
    ns_instruction_set,
    ns_operator,
    Grid,
    MechState,
    AtomState,
    AtomFaucetState,
    AtomSinkState,
    BoardConfig,
)
from contracts.events import Check
from contracts.utils import emit_arr

@external
func simulator{syscall_ptr: felt*, range_check_ptr}(
    n_cycles: felt,
    board_dimension: felt,
    mechs_len: felt,
    mechs: MechState*,
    atoms_len: felt,
    atoms: AtomState*,
    instructions_sets_len: felt,
    instructions_sets: felt*,
    instructions_len: felt,
    instructions: felt*,
    atom_faucets_len: felt,
    atom_faucets: AtomFaucetState*,
    atom_sinks_len: felt,
    atom_sinks: AtomSinkState*,
    operator_input_len: felt,
    operator_input: Grid*,
    operator_output_len: felt,
    operator_output: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
) {
    alloc_locals;
    // verify the operators are valid
    ns_operator.verify_valid(operators_type_len, operators_type, operator_input, operator_output);

    //
    // Calculate base cost based on number of operators and number of mechs used
    //
    let base_cost_operators = ns_operator_type.get_operators_cost(
        operators_type_len, operators_type, 0
    );
    let base_cost_mechs = ns_mech_type.get_mechs_cost(mechs_len, mechs, 0);
    local base_cost = base_cost_operators + base_cost_mechs;

    //
    // Forward system by n_cycles, emitting frames; a frame carries all objects with their states i.e. frame == state screenshot
    //
    simulate_loop(
        n_cycles,
        0,
        instructions_sets_len,
        instructions_sets,
        instructions_len,
        instructions,
        mechs_len,
        mechs,
        atoms_len,
        atoms,
        atom_faucets_len,
        atom_faucets,
    );

    return ();
}

func simulate_loop{syscall_ptr: felt*, range_check_ptr}(
    n_cycles: felt,
    cycle: felt,
    instructions_sets_len: felt,
    instructions_sets: felt*,
    instructions_len: felt,
    instructions: felt*,
    mechs_len: felt,
    mechs: MechState*,
    atoms_len: felt,
    atoms: AtomState*,
    atom_faucets_len: felt,
    atom_faucets: AtomFaucetState*,
) {
    alloc_locals;
    if (cycle == n_cycles) {
        return ();
    }
    // get current frame instructions
    let (local frame_instructions: felt*) = alloc();
    ns_instruction_set.get_frame_instruction_set(
        cycle, instructions_sets_len, instructions_sets, instructions, 0, frame_instructions, 0
    );

    // simulate one frame based on current state + instructions
    simulate_one_frame(
        instructions_sets_len,
        frame_instructions,
        mechs_len,
        mechs,
        atoms_len,
        atoms,
        atom_faucets_len,
        atom_faucets,
    );

    simulate_loop(
        n_cycles,
        cycle + 1,
        instructions_sets_len,
        instructions_sets,
        instructions_len,
        instructions,
        mechs_len,
        mechs,
        atoms_len,
        atoms,
        atom_faucets_len,
        atom_faucets,
    );
    return ();
}

func simulate_one_frame{syscall_ptr: felt*, range_check_ptr}(
    instructions_len: felt,
    instructions: felt*,
    mechs_len: felt,
    mechs: MechState*,
    atoms_len: felt,
    atoms: AtomState*,
    atom_faucets_len: felt,
    atom_faucets: AtomFaucetState*,
) {
    return ();
}
