%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math_cmp import is_le

from contracts.constants import Grid, ns_mechs, ns_instructions
from contracts.atoms import AtomState, update_atoms_moved

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

func iterate_mechs{range_check_ptr}(
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
    let can_move_right = is_le(mech.index.x, board_dimension - 2);
    if (instruction == ns_instructions.D and can_move_right == 1) {
        tempvar len_1 = i * ns_mechs.MECH_SIZE;
        tempvar len_2 = (mechs_len - i - 1) * ns_mechs.MECH_SIZE;
        let (mechs_new) = update_mechs(len_1, len_2, mech, mechs);
        let (is_moved, atoms_new) = update_atoms_moved(mech.id, mech.index, 0, atoms_len, atoms);
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
    if (instruction == ns_instructions.Z) {
        let (is_moved, atoms_new) = update_atoms_moved(mech.id, mech.index, 0, atoms_len, atoms);
        let (a, m) = iterate_mechs(
            board_dimension,
            mechs_len,
            mechs,
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

func update_mechs{range_check_ptr}(
    len_1: felt, len_2: felt, mech: MechState, mechs: MechState*
) -> (mechs_new: MechState*) {
    alloc_locals;
    let (local mechs_new: MechState*) = alloc();
    memcpy(mechs_new, mechs, len_1);
    assert [mechs_new + len_1] = MechState(mech.id, mech.type, mech.status, Grid(mech.index.x + 1, mech.index.y));
    memcpy(mechs_new + len_1 + ns_mechs.MECH_SIZE, mechs + len_1 + ns_mechs.MECH_SIZE, len_2);
    return (mechs_new=mechs_new);
}
