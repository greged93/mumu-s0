%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import get_caller_address

from contracts.constants import ns_mechs, ns_atoms, ns_instructions, ns_grid

from contracts.mechs import MechState, get_mechs_cost, iterate_mechs
from contracts.atoms import (
    AtomState,
    AtomFaucetState,
    AtomSinkState,
    populate_faucets,
    iterate_sinks,
)
from contracts.operators import verify_valid, get_operators_cost, iterate_operators
from contracts.instructions import get_frame_instruction_set
from contracts.grid import Grid

from contracts.events import new_simulation, frame

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
    operators_inputs_len: felt,
    operators_inputs: Grid*,
    operators_outputs_len: felt,
    operators_outputs: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
) {
    alloc_locals;
    // verify the operators are valid
    verify_valid(operators_type_len, operators_type, operators_inputs, operators_outputs);

    //
    // Calculate base cost based on number of operators and number of mechs used
    //
    let base_cost_operators = get_operators_cost(operators_type_len, operators_type, 0);
    let base_cost_mechs = get_mechs_cost(mechs_len, mechs, 0);
    local base_cost = base_cost_operators + base_cost_mechs;

    let (caller) = get_caller_address();

    new_simulation.emit(
        solver=caller,
        mechs_len=mechs_len,
        mechs=mechs,
        atoms_len=atoms_len,
        atoms=atoms,
        instructions_sets_len=instructions_sets_len,
        instructions_sets=instructions_sets,
        instructions_len=instructions_len,
        instructions=instructions,
        cost_accumulated=base_cost,
    );

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
        operators_inputs_len,
        operators_inputs,
        operators_outputs_len,
        operators_outputs,
        operators_type_len,
        operators_type,
        base_cost,
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
    operators_inputs_len: felt,
    operators_inputs: Grid*,
    operators_outputs_len: felt,
    operators_outputs: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
    cost: felt,
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
    let (mechs_new, atoms_len_new, atoms_new, cost_increase) = simulate_one_frame(
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
        operators_inputs_len,
        operators_inputs,
        operators_outputs_len,
        operators_outputs,
        operators_type_len,
        operators_type,
    );

    tempvar new_cost = cost + cost_increase;

    frame.emit(
        mechs_len=mechs_len,
        mechs=mechs_new,
        atoms_len=atoms_len_new,
        atoms=atoms_new,
        cost_accumulated=new_cost,
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
        mechs_new,
        atoms_len_new,
        atoms_new,
        atom_faucets_len,
        atom_faucets,
        atom_sinks_len,
        atom_sinks,
        operators_inputs_len,
        operators_inputs,
        operators_outputs_len,
        operators_outputs,
        operators_type_len,
        operators_type,
        new_cost,
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
    operators_inputs_len: felt,
    operators_inputs: Grid*,
    operators_outputs_len: felt,
    operators_outputs: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
) -> (mechs_new: MechState*, atoms_len_new: felt, atoms_new: AtomState*, cost_increase: felt) {
    alloc_locals;

    let (atoms_new: AtomState*) = alloc();
    memcpy(atoms_new, atoms, atoms_len * ns_atoms.ATOM_STATE_SIZE);
    let atoms_len_new = populate_faucets(atom_faucets_len, atom_faucets, atoms_len, atoms_new);

    //
    // Iterate through mechs
    //
    let (atoms_new, mechs_new, cost_increase) = iterate_mechs(
        board_dimension,
        mechs_len,
        mechs,
        0,
        instructions_len,
        instructions,
        atoms_len_new,
        atoms_new,
        0,
    );

    //
    // Iterate through operators
    //
    let (atoms_len_new, atoms_new) = iterate_operators(
        atoms_len_new,
        atoms_new,
        operators_inputs,
        operators_outputs,
        operators_type_len,
        operators_type,
    );

    //
    // Iterate through atom sinks
    //
    let (atoms_len_new, atoms_new) = iterate_sinks(
        atom_sinks_len, atom_sinks, atoms_len_new, atoms_new
    );

    return (mechs_new, atoms_len_new, atoms_new, cost_increase);
}
