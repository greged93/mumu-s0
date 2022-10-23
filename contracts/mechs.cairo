%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math_cmp import is_le

from contracts.constants import ns_mechs, ns_instructions, ns_atoms, ns_instructions_cost
from contracts.grid import Grid
from contracts.atoms import (
    AtomState,
    update_atoms_moved,
    release_atom,
    pick_up_atom,
    check_grid_free,
    check_grid_filled,
)

from contracts.events import Check

struct MechState {
    id: felt,
    type: felt,
    status: felt,
    index: Grid,
}

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

func iterate_mechs{syscall_ptr: felt*, range_check_ptr}(
    board_dimension: felt,
    mechs_len: felt,
    mechs: MechState*,
    i: felt,
    instructions_len: felt,
    instructions: felt*,
    atoms_len: felt,
    atoms: AtomState*,
    cost_increase: felt,
) -> (atoms: AtomState*, mechs: MechState*, cost_increase: felt) {
    alloc_locals;
    if (instructions_len == i) {
        return (atoms, mechs, cost_increase);
    }

    tempvar instruction = [instructions + i];
    tempvar mech = [mechs + i * ns_mechs.MECH_SIZE];
    tempvar len_1 = i * ns_mechs.MECH_SIZE;
    tempvar len_2 = (mechs_len - i - 1) * ns_mechs.MECH_SIZE;

    let can_move_right = is_le(mech.index.x, board_dimension - 2);
    if (instruction == ns_instructions.D and can_move_right == 1) {
        let (mechs_new) = update_mechs_moved(len_1, len_2, mech, mechs, 1, 0);
        let has_atom = check_possesses_atom(mech.id, atoms_len, atoms);
        let inc = get_cost_increase(has_atom);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
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
        let has_atom = check_possesses_atom(mech.id, atoms_len, atoms);
        let inc = get_cost_increase(has_atom);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
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
        let has_atom = check_possesses_atom(mech.id, atoms_len, atoms);
        let inc = get_cost_increase(has_atom);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
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
        let has_atom = check_possesses_atom(mech.id, atoms_len, atoms);
        let inc = get_cost_increase(has_atom);
        return iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
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
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_PUT,
        );
    }
    return iterate_mechs(
        board_dimension,
        mechs_len,
        mechs,
        i + 1,
        instructions_len,
        instructions,
        atoms_len,
        atoms,
        cost_increase,
    );
}

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

func get_cost_increase{}(is_moved: felt) -> felt {
    if (is_moved == 1) {
        return ns_instructions_cost.SINGLETON_MOVE_CARRY;
    } else {
        return ns_instructions_cost.SINGLETON_MOVE_EMPTY;
    }
}
