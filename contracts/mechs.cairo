%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math_cmp import is_le

from contracts.constants import Grid, ns_mechs, ns_instructions, ns_atoms
from contracts.atoms import AtomState, update_atoms_moved, update_atoms_status

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
) -> (atoms: AtomState*, mechs: MechState*) {
    alloc_locals;
    if (instructions_len == i) {
        return (atoms, mechs);
    }

    tempvar instruction = [instructions + i];
    tempvar mech = [mechs + i * ns_mechs.MECH_SIZE];
    tempvar len_1 = i * ns_mechs.MECH_SIZE;
    tempvar len_2 = (mechs_len - i - 1) * ns_mechs.MECH_SIZE;

    let can_move_right = is_le(mech.index.x, board_dimension - 2);
    if (instruction == ns_instructions.D and can_move_right == 1) {
        let (mechs_new) = update_mechs_moved(len_1, len_2, mech, mechs, 1, 0);
        let (is_moved, atoms_new) = update_atoms_moved(
            mech.id, Grid(mech.index.x + 1, mech.index.y), 0, atoms_len, atoms
        );
        let (a, m) = iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase,
        );
        return (a, m);
    }
    let can_move_left = is_le(1, mech.index.x);
    if (instruction == ns_instructions.A and can_move_left == 1) {
        let (mechs_new) = update_mechs_moved(len_1, len_2, mech, mechs, -1, 0);
        let (is_moved, atoms_new) = update_atoms_moved(
            mech.id, Grid(mech.index.x - 1, mech.index.y), 0, atoms_len, atoms
        );
        let (a, m) = iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase,
        );
        return (a, m);
    }
    let can_move_down = is_le(mech.index.y, board_dimension - 2);
    if (instruction == ns_instructions.S and can_move_down == 1) {
        let (mechs_new) = update_mechs_moved(len_1, len_2, mech, mechs, 0, 1);
        let (is_moved, atoms_new) = update_atoms_moved(
            mech.id, Grid(mech.index.x, mech.index.y + 1), 0, atoms_len, atoms
        );
        let (a, m) = iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase,
        );
        return (a, m);
    }
    let can_move_up = is_le(1, mech.index.y);
    if (instruction == ns_instructions.W and can_move_up == 1) {
        let (mechs_new) = update_mechs_moved(len_1, len_2, mech, mechs, 0, -1);
        let (is_moved, atoms_new) = update_atoms_moved(
            mech.id, Grid(mech.index.x, mech.index.y - 1), 0, atoms_len, atoms
        );
        let (a, m) = iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase,
        );
        return (a, m);
    }
    if (instruction == ns_instructions.Z and mech.status == ns_mechs.OPEN) {
        let (atoms_new) = update_atoms_status(
            mech.id, mech.index, 0, atoms_len, atoms, ns_atoms.POSSESSED
        );
        let (mechs_new) = update_mechs_status(len_1, len_2, mech, mechs, ns_mechs.CLOSE);
        let (a, m) = iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase,
        );
        return (a, m);
    }
    if (instruction == ns_instructions.X and mech.status == ns_mechs.CLOSE) {
        let (atoms_new) = update_atoms_status(
            mech.id, mech.index, 0, atoms_len, atoms, ns_atoms.FREE
        );
        let (mechs_new) = update_mechs_status(len_1, len_2, mech, mechs, ns_mechs.OPEN);
        let (a, m) = iterate_mechs(
            board_dimension,
            mechs_len,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_len,
            atoms_new,
            cost_increase,
        );
        return (a, m);
    }
    let (a, m) = iterate_mechs(
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
    return (a, m);
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
