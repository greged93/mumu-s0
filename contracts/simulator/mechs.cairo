%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math_cmp import is_le

from contracts.simulator.constants import ns_mechs, ns_instructions, ns_atoms, ns_instructions_cost
from contracts.simulator.grid import Grid
from contracts.simulator.atoms import (
    AtomState,
    update_atoms_moved,
    release_atom,
    pick_up_atom,
    check_grid_free,
    check_grid_filled,
)

struct MechState {
    id: felt,
    type: felt,
    status: felt,
    index: Grid,
}

// @notice Verifies all mechs are within bounds
// @param mechs The array of mechs
// @param dimension The dimensions of the board
func verify_bounded_mechs{range_check_ptr}(mechs_len: felt, mechs: MechState*, dimension: felt) {
    if (mechs_len == 0) {
        return ();
    }
    tempvar mech = [mechs];
    with_attr error_message("mech not within bounds") {
        assert [range_check_ptr] = dimension - mech.index.x - 1;
        assert [range_check_ptr + 1] = dimension - mech.index.y - 1;
    }
    let range_check_ptr = range_check_ptr + 2;
    return verify_bounded_mechs(mechs_len - 1, mechs + ns_mechs.MECH_SIZE, dimension);
}

// @notice Returns the total costs for mechs
// @param mechs The array of mechs
// @param sum The sum of cost for mechs
// @return The total cost for mechs
func get_mechs_cost{range_check_ptr}(mechs_len: felt, mechs: MechState*, sum: felt) -> felt {
    if (mechs_len == 0) {
        return sum;
    }
    tempvar cost;
    tempvar mech = [mechs];
    if (mech.type == ns_mechs.SINGLETON) {
        assert cost = ns_mechs.STATIC_COST_SINGLETON;
    }
    return get_mechs_cost(mechs_len - 1, mechs + ns_mechs.MECH_SIZE, sum + cost);
}

// @notice Iterates mechs and applies instructions
// @param board_dimension The dimensions of the board
// @param mechs The array of mechs
// @param i The current mech index
// @param instructions The array of instructions for each mech
// @param atoms The array of atoms on the board
// @param pc The array of program counters
// @param cost_increase The sum of increase in cost from mechs operations
// @return atoms_new The array of updated atoms
// @return mechs_new The array of updated mechs
// @return cost_increase The increase in cost from mechs operations
func iterate_mechs{syscall_ptr: felt*, range_check_ptr}(
    board_dimension: felt,
    mechs_len: felt,
    mechs: MechState*,
    pc: felt*,
    i: felt,
    instructions_len: felt,
    instructions: felt*,
    atoms_len: felt,
    atoms: AtomState*,
    cost_increase: felt,
) -> (atoms: AtomState*, mechs: MechState*, pc: felt*, cost_increase: felt) {
    alloc_locals;
    if (instructions_len == i) {
        return (atoms, mechs, pc, cost_increase);
    }

    tempvar instruction = [instructions + i];
    tempvar mech = [mechs + i * ns_mechs.MECH_SIZE];
    tempvar len_1 = i * ns_mechs.MECH_SIZE;
    tempvar len_2 = (mechs_len - i - 1) * ns_mechs.MECH_SIZE;

    let can_move_right = is_le(mech.index.x, board_dimension - 2);
    if (instruction == ns_instructions.D and can_move_right == 1) {
        let (mechs_new) = update_mechs_moved(len_1, len_2, mech, mechs, 1, 0);
        let inc = get_cost_increase(mech.status);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            pc,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms,
            cost_increase + inc,
        );
    }
    let can_move_left = is_le(1, mech.index.x);
    if (instruction == ns_instructions.A and can_move_left == 1) {
        let (mechs_new) = update_mechs_moved(len_1, len_2, mech, mechs, -1, 0);
        let inc = get_cost_increase(mech.status);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            pc,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms,
            cost_increase + inc,
        );
    }
    let can_move_down = is_le(mech.index.y, board_dimension - 2);
    if (instruction == ns_instructions.S and can_move_down == 1) {
        let (mechs_new) = update_mechs_moved(len_1, len_2, mech, mechs, 0, 1);
        let inc = get_cost_increase(mech.status);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            pc,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms,
            cost_increase + inc,
        );
    }
    let can_move_up = is_le(1, mech.index.y);
    if (instruction == ns_instructions.W and can_move_up == 1) {
        let (mechs_new) = update_mechs_moved(len_1, len_2, mech, mechs, 0, -1);
        let inc = get_cost_increase(mech.status);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            pc,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms,
            cost_increase + inc,
        );
    }
    let is_filled = check_grid_filled(mech.index, atoms_len, atoms);
    if (instruction == ns_instructions.Z and mech.status == ns_mechs.OPEN and is_filled == 1) {
        let (atoms_new) = pick_up_atom(mech.id, mech.index, 0, atoms_len, atoms);
        let (mechs_new) = update_mechs_status(len_1, len_2, mech, mechs, ns_mechs.CLOSE);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            pc,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_GET,
        );
    }
    let is_free = check_grid_free(mech.index, atoms_len, atoms);
    if (instruction == ns_instructions.X and mech.status == ns_mechs.CLOSE and is_free == 1) {
        let (atoms_new) = release_atom(mech.id, mech.index, 0, atoms_len, atoms);
        let (mechs_new) = update_mechs_status(len_1, len_2, mech, mechs, ns_mechs.OPEN);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            pc,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_PUT,
        );
    }
    if (instruction == ns_instructions.G and mech.status == ns_mechs.OPEN and is_filled == 1) {
        let (atoms_new) = pick_up_atom(mech.id, mech.index, 0, atoms_len, atoms);
        let (mechs_new) = update_mechs_status(len_1, len_2, mech, mechs, ns_mechs.CLOSE);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            pc,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_GET,
        );
    }
    if (instruction == ns_instructions.G and mech.status == ns_mechs.OPEN and is_filled == 0) {
        let (pc_new) = substract_pc(mechs_len, pc, i);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs,
            pc_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms,
            cost_increase + ns_instructions_cost.SINGLETON_BLOCKED,
        );
    }
    if (instruction == ns_instructions.H and mech.status == ns_mechs.CLOSE and is_free == 1) {
        let (atoms_new) = release_atom(mech.id, mech.index, 0, atoms_len, atoms);
        let (mechs_new) = update_mechs_status(len_1, len_2, mech, mechs, ns_mechs.OPEN);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            pc,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_PUT,
        );
    }
    if (instruction == ns_instructions.H and mech.status == ns_mechs.CLOSE and is_free == 0) {
        let (pc_new) = substract_pc(mechs_len, pc, i);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs,
            pc_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms,
            cost_increase + ns_instructions_cost.SINGLETON_BLOCKED,
        );
    }
    return iterate_mechs(
        board_dimension,
        mechs_len,
        mechs,
        pc,
        i + 1,
        instructions_len,
        instructions,
        atoms_len,
        atoms,
        cost_increase,
    );
}

// @notice Initiates pc array to zero
// @param pc The current empty pc array
// @param i The current mech index
// @return pc The empty pc array
func init_pc{range_check_ptr}(pc_len: felt, pc: felt*, i: felt) -> (pc: felt*) {
    if (pc_len == 0) {
        return (pc=pc);
    }
    assert [pc + i] = 0;
    return init_pc(pc_len - 1, pc, i + 1);
}

// @notice Substracts one to mech pc
// @param pc The array of program counters for mechs
// @param i The current mech index
// @return The updated program counters
func substract_pc{range_check_ptr}(pc_len: felt, pc: felt*, i: felt) -> (pc_new: felt*) {
    alloc_locals;
    let (pc_new) = alloc();
    memcpy(pc_new, pc, i);
    assert [pc_new + i] = [pc + i] - 1;
    memcpy(pc_new + i + 1, pc + i + 1, pc_len - i - 1);
    return (pc_new=pc_new);
}

// @notice Updates the mechs array after movement
// @param len_1 The length of the first part of invariant mechs
// @param len_2 The length of the second part of invariant mechs
// @param mech The updated mech
// @param mechs The array of mechs
// @param x_inc The x position increase
// @param y_inc The y position increase
// @return mechs_new The array of updated mechs
func update_mechs_moved{range_check_ptr}(
    len_1: felt, len_2: felt, mech: MechState, mechs: MechState*, x_inc: felt, y_inc: felt
) -> (mechs_new: MechState*) {
    alloc_locals;
    let (local mechs_new: MechState*) = alloc();
    memcpy(mechs_new, mechs, len_1);
    assert [mechs_new + len_1] = MechState(mech.id, mech.type, mech.status, Grid(mech.index.x + x_inc, mech.index.y + y_inc));
    memcpy(mechs_new + len_1 + ns_mechs.MECH_SIZE, mechs + len_1 + ns_mechs.MECH_SIZE, len_2);
    return (mechs_new=mechs_new);
}

// @notice Updates the mechs array after status update
// @param len_1 The length of the first part of invariant mechs
// @param len_2 The length of the second part of invariant mechs
// @param mech The updated mech
// @param mechs The array of mechs
// @param status The new mech status
// @return mechs_new The array of updated mechs
func update_mechs_status{range_check_ptr}(
    len_1: felt, len_2: felt, mech: MechState, mechs: MechState*, status: felt
) -> (mechs_new: MechState*) {
    alloc_locals;
    let (local mechs_new: MechState*) = alloc();
    memcpy(mechs_new, mechs, len_1);
    assert [mechs_new + len_1] = MechState(mech.id, mech.type, status, mech.index);
    memcpy(mechs_new + len_1 + ns_mechs.MECH_SIZE, mechs + len_1 + ns_mechs.MECH_SIZE, len_2);
    return (mechs_new=mechs_new);
}

// @notice Checks if the mech possesses an atom
// @param mech_id The id of the mech
// @param atoms The array of atoms
// @return 1 if the mech possesses an atom, 0 otherwise
func check_possesses_atom{range_check_ptr}(
    mech_id: felt, atoms_len: felt, atoms: AtomState*
) -> felt {
    if (atoms_len == 0) {
        return 0;
    }
    tempvar atom = [atoms];
    if (atom.status == ns_atoms.POSSESSED and atom.possessed_by == mech_id) {
        return 1;
    }
    return check_possesses_atom(mech_id, atoms_len - 1, atoms + ns_atoms.ATOM_STATE_SIZE);
}

// @notice Returns the cost increase due to mech movement
// @param is_moved 1 if mech moved, 0 otherwise
// @return The cost due to mech movement
func get_cost_increase{}(is_moved: felt) -> felt {
    if (is_moved == 1) {
        return ns_instructions_cost.SINGLETON_MOVE_CARRY;
    } else {
        return ns_instructions_cost.SINGLETON_MOVE_EMPTY;
    }
}
