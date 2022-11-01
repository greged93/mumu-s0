%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address

from contracts.simulator.constants import (
    ns_summary,
    ns_mechs,
    ns_atoms,
    ns_instructions,
    ns_grid,
    Summary,
)

from contracts.simulator.mechs import (
    MechState,
    verify_bounded_mechs,
    get_mechs_cost,
    iterate_mechs,
    init_pc,
)
from contracts.simulator.atoms import (
    AtomState,
    AtomFaucetState,
    AtomSinkState,
    populate_faucet,
    iterate_sinks,
)
from contracts.simulator.operators import (
    verify_valid_operators,
    get_operators_cost,
    iterate_operators,
)
from contracts.simulator.instructions import get_frame_instruction_set
from contracts.simulator.grid import Grid

from contracts.simulator.events import new_simulation, end_summary

// @notice Simulates the run for current inputs for 100 cycles
// @param board_dimension The dimensions of the board
// @param mechs The array of mechs
// @param instructions_sets The length of each mech's instructions
// @param instructions The array of all mechs' instructions concatenated together
// @param operators_inputs The array of operators inputs
// @param operators_output The array of operators outputs
// @param operators_type The array of operators type
@external
func simulator{syscall_ptr: felt*, range_check_ptr}(
    mechs_len: felt,
    mechs: MechState*,
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
) {
    alloc_locals;
    let board_dimension = 7;

    // verify the operators are valid following 3 rules
    verify_valid_operators(
        operators_type_len,
        operators_type,
        operators_inputs_len,
        operators_inputs,
        operators_outputs_len,
        operators_outputs,
        board_dimension,
    );
    // verify the mechs are bounded
    verify_bounded_mechs(mechs_len, mechs, board_dimension);

    //
    // Calculate base cost based on number of operators and number of mechs used
    //
    let base_cost_operators = get_operators_cost(operators_type_len, operators_type, 0);
    let base_cost_mechs = get_mechs_cost(mechs_len, mechs, 0);
    local base_cost = base_cost_operators + base_cost_mechs;

    //
    // Emit new simulation event
    //
    let (caller) = get_caller_address();
    new_simulation.emit(
        solver=caller,
        mechs_len=mechs_len,
        mechs=mechs,
        instructions_sets_len=instructions_sets_len,
        instructions_sets=instructions_sets,
        instructions_len=instructions_len,
        instructions=instructions,
        operators_inputs_len=operators_inputs_len,
        operators_inputs=operators_inputs,
        operators_outputs_len=operators_outputs_len,
        operators_outputs=operators_outputs,
        operators_type_len=operators_type_len,
        operators_type=operators_type,
        static_cost=base_cost,
    );

    //
    // Create the empty pc array
    //
    let (pc: felt*) = alloc();
    let (pc_empty) = init_pc(mechs_len, pc, 0);

    //
    // Create the sink array
    //
    let (atom_sinks: AtomSinkState*) = alloc();
    assert atom_sinks[0] = AtomSinkState(0, Grid(board_dimension - 1, 0));
    assert atom_sinks[1] = AtomSinkState(0, Grid(0, board_dimension - 1));
    assert atom_sinks[2] = AtomSinkState(0, Grid(board_dimension - 1, board_dimension - 1));

    let (atoms: AtomState*) = alloc();

    //
    // Forward system by 80, emitting summary frame at end of iterations;
    //
    simulate_loop(
        80,
        0,
        board_dimension,
        instructions_sets_len,
        instructions_sets,
        instructions_len,
        instructions,
        mechs_len,
        mechs,
        pc_empty,
        0,
        atoms,
        AtomFaucetState(0, 0, Grid(0, 0)),
        3,
        atom_sinks,
        operators_inputs_len,
        operators_inputs,
        operators_outputs_len,
        operators_outputs,
        operators_type_len,
        operators_type,
        Summary(0, base_cost, base_cost, 0, 0),
    );

    return ();
}

// @notice Simulates the run for current inputs for n_cycles cycles
// @param n_cycles The amount of cycles to simulate
// @param cyle The current cycle
// @param board_dimension The dimensions of the board
// @param instructions_sets The length of each mech's instructions
// @param instructions The array of all mechs' instructions concatenated together
// @param mechs The array of mechs
// @param pc The array of program counters
// @param atoms The arrays of atoms
// @param atom_faucet The atom faucet
// @param atom_sinks The array of sinks
// @param operators_inputs The array of operators inputs
// @param operators_output The array of operators outputs
// @param operators_type The array of operators type
// @param summary The summary for the simulation
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
    pc: felt*,
    atoms_len: felt,
    atoms: AtomState*,
    atom_faucet: AtomFaucetState,
    atom_sinks_len: felt,
    atom_sinks: AtomSinkState*,
    operators_inputs_len: felt,
    operators_inputs: Grid*,
    operators_outputs_len: felt,
    operators_outputs: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
    summary: Summary,
) {
    alloc_locals;
    if (cycle == n_cycles) {
        tempvar delivered = summary.delivered;
        if (delivered == 0) {
            end_summary.emit(delivered=0, latency=ns_summary.INF, dynamic_cost=ns_summary.INF);
        } else {
            let (average_dynamic_cost, _) = unsigned_div_rem(
                (summary.delivered_cost - summary.static_cost) * ns_summary.PRECISION, delivered
            );
            let (average_latency, _) = unsigned_div_rem(
                summary.frame * ns_summary.PRECISION, delivered
            );
            end_summary.emit(
                delivered=delivered, latency=average_latency, dynamic_cost=average_dynamic_cost
            );
        }
        return ();
    }
    // get current frame instructions
    let (local frame_instructions: felt*) = alloc();
    get_frame_instruction_set(
        cycle, pc, instructions_sets_len, instructions_sets, instructions, 0, frame_instructions, 0
    );

    // simulate one frame based on current state + instructions
    let (mechs_new, pc_new, atoms_len_new, atoms_new, summary_new) = simulate_one_frame(
        board_dimension,
        cycle,
        instructions_sets_len,
        frame_instructions,
        mechs_len,
        mechs,
        pc,
        atoms_len,
        atoms,
        atom_faucet,
        atom_sinks_len,
        atom_sinks,
        operators_inputs_len,
        operators_inputs,
        operators_outputs_len,
        operators_outputs,
        operators_type_len,
        operators_type,
        summary,
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
        pc_new,
        atoms_len_new,
        atoms_new,
        atom_faucet,
        atom_sinks_len,
        atom_sinks,
        operators_inputs_len,
        operators_inputs,
        operators_outputs_len,
        operators_outputs,
        operators_type_len,
        operators_type,
        summary_new,
    );
    return ();
}

// @notice Simulates the run for current inputs for one cycle
// @param board_dimension The dimensions of the board
// @param cycle The simulation cycle
// @param instructions The frame's instruction for each mech
// @param mechs The array of mechs
// @param pc The array of program counters
// @param atoms The arrays of atoms
// @param atom_faucet The atom faucet
// @param atom_sinks The array of sinks
// @param operators_inputs The array of operators inputs
// @param operators_output The array of operators outputs
// @param operators_type The array of operators type
// @param summary The summary of the simulation
// @return mechs_new The array of updated mechs
// @return atoms_len_new The length of updated atoms
// @return atoms_new The array of updated atoms
// @return summary_new The change in simulation summary
func simulate_one_frame{syscall_ptr: felt*, range_check_ptr}(
    board_dimension: felt,
    cycle: felt,
    instructions_len: felt,
    instructions: felt*,
    mechs_len: felt,
    mechs: MechState*,
    pc: felt*,
    atoms_len: felt,
    atoms: AtomState*,
    atom_faucet: AtomFaucetState,
    atom_sinks_len: felt,
    atom_sinks: AtomSinkState*,
    operators_inputs_len: felt,
    operators_inputs: Grid*,
    operators_outputs_len: felt,
    operators_outputs: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
    summary: Summary,
) -> (
    mechs_new: MechState*,
    pc_new: felt*,
    atoms_len_new: felt,
    atoms_new: AtomState*,
    summary_new: Summary,
) {
    alloc_locals;

    let (atoms_new: AtomState*) = alloc();
    memcpy(atoms_new, atoms, atoms_len * ns_atoms.ATOM_STATE_SIZE);
    let atoms_len_new = populate_faucet(atom_faucet, atoms_len, atoms_new);

    //
    // Iterate through mechs
    //
    let (atoms_new, mechs_new, pc_new, cost_increase) = iterate_mechs(
        board_dimension,
        mechs_len,
        mechs,
        pc,
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
    let (atoms_len_new, atoms_new, delivered_increase) = iterate_sinks(
        atom_sinks_len, atom_sinks, atoms_len_new, atoms_new, 0
    );

    tempvar cost_new = summary.cost + cost_increase;
    if (delivered_increase == 0) {
        tempvar summary_new = Summary(summary.frame, cost_new, summary.static_cost, summary.delivered_cost, summary.delivered);
    } else {
        tempvar summary_new = Summary(cycle + 1, cost_new, summary.static_cost, cost_new, summary.delivered + delivered_increase);
    }

    return (mechs_new, pc_new, atoms_len_new, atoms_new, summary_new);
}
