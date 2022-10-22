%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

from contracts.constants import ns_mechs, ns_atoms, ns_instructions, ns_grid, Grid

from contracts.mechs import MechState, get_mechs_cost, iterate_mechs
from contracts.atoms import AtomState, AtomFaucetState, AtomSinkState, populate_faucets
from contracts.operators import verify_valid, get_operators_cost
from contracts.instructions import get_frame_instruction_set

from contracts.events import Check
from contracts.utils import emit_arr, emit_grid_arr, emit_mechs

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
    verify_valid(operators_type_len, operators_type, operator_input, operator_output);

    //
    // Calculate base cost based on number of operators and number of mechs used
    //
    let base_cost_operators = get_operators_cost(operators_type_len, operators_type, 0);
    let base_cost_mechs = get_mechs_cost(mechs_len, mechs, 0);
    local base_cost = base_cost_operators + base_cost_mechs;

    //
    // Forward system by n_cycles, emitting frames; a frame carries all objects with their states i.e. frame == state screenshot
    //
    simulate_loop(
        n_cycles,
        0,
        board_dimension,
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
        atom_sinks_len,
        atom_sinks,
        operator_input_len,
        operator_input,
        operator_output_len,
        operator_output,
        operators_type_len,
        operators_type,
    );

    return ();
}

func simulate_loop{syscall_ptr: felt*, range_check_ptr}(
    n_cycles: felt,
    cycle: felt,
    board_dimension: felt,
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
    if (cycle == n_cycles) {
        return ();
    }
    // get current frame instructions
    let (local frame_instructions: felt*) = alloc();
    get_frame_instruction_set(
        cycle, instructions_sets_len, instructions_sets, instructions, 0, frame_instructions, 0
    );

    // simulate one frame based on current state + instructions
    simulate_one_frame(
        board_dimension,
        instructions_sets_len,
        frame_instructions,
        mechs_len,
        mechs,
        atoms_len,
        atoms,
        atom_faucets_len,
        atom_faucets,
        atom_sinks_len,
        atom_sinks,
        operator_input_len,
        operator_input,
        operator_output_len,
        operator_output,
        operators_type_len,
        operators_type,
    );

    simulate_loop(
        n_cycles,
        cycle + 1,
        board_dimension,
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
        atom_sinks_len,
        atom_sinks,
        operator_input_len,
        operator_input,
        operator_output_len,
        operator_output,
        operators_type_len,
        operators_type,
    );
    return ();
}

func simulate_one_frame{syscall_ptr: felt*, range_check_ptr}(
    board_dimension: felt,
    instructions_len: felt,
    instructions: felt*,
    mechs_len: felt,
    mechs: MechState*,
    atoms_len: felt,
    atoms: AtomState*,
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
    let (atoms_new: AtomState*) = alloc();
    memcpy(atoms_new, atoms, atoms_len * ns_atoms.ATOM_STATE_SIZE);
    let atoms_len_new = populate_faucets(atom_faucets_len, atom_faucets, atoms_len, atoms_new);

    //
    // Iterate through mechs
    //
    let (atoms_new, mechs_new) = iterate_mechs(
        board_dimension, mechs_len, mechs, 0, instructions_len, instructions, atoms_len, atoms, 0
    );
    // emit_arr(atom_len_new * ns_atom_state.ATOM_STATE_SIZE, atoms_new);
    emit_mechs(mechs_len, mechs_new);
    return ();
}
