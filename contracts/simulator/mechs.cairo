%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_write, dict_read

from contracts.simulator.constants import ns_mechs, ns_instructions, ns_atoms, ns_instructions_cost
from contracts.simulator.grid import Grid
from contracts.simulator.atoms import (
    AtomState,
    release_atom,
    pick_up_atom,
    check_grid_free,
    check_grid_filled,
)

struct InputMechState {
    id: felt,
    type: felt,
    status: felt,
    index: Grid,
}

struct MechState {
    id: felt,
    type: felt,
    status: felt,
    index: Grid,
    pc: felt,
}

// @notice Initiates the dictionary of mechs and verifies mechs are within bounds
// @param mechs_count The mech count
// @param mechs The array of mechs
// @param dict The dictionary of mechs
// @param dimension The dimensions of the board
// @return dict_new The updated dictionary of mechs
func init_mechs{range_check_ptr}(
    mechs_count: felt, mechs: InputMechState*, dict: DictAccess*, dimension: felt
) -> (dict_new: DictAccess*) {
    if (mechs_count == 0) {
        return (dict_new=dict);
    }
    tempvar mech: InputMechState = [mechs];

    let (ptr) = dict_read{dict_ptr=dict}(key=mech.id);
    with_attr error_message("mech ids must be different") {
        assert ptr = 0;
    }

    with_attr error_message("mech not within bounds") {
        assert [range_check_ptr] = dimension - mech.index.x - 1;
        assert [range_check_ptr + 1] = dimension - mech.index.y - 1;
    }
    let range_check_ptr = range_check_ptr + 2;

    tempvar new_mech: MechState* = new MechState(mech.id, mech.type, mech.status, mech.index, 0);
    dict_write{dict_ptr=dict}(key=mech.id, new_value=cast(new_mech, felt));
    return init_mechs(mechs_count - 1, mechs + ns_mechs.INPUT_MECH_SIZE, dict, dimension);
}

// @notice Returns the total costs for mechs
// @param mechs The array of mechs
// @param sum The sum of cost for mechs
// @return The total cost for mechs
func get_mechs_cost{range_check_ptr}(mechs_len: felt, mechs: InputMechState*, sum: felt) -> felt {
    if (mechs_len == 0) {
        return sum;
    }
    tempvar cost;
    tempvar mech = [mechs];
    if (mech.type == ns_mechs.SINGLETON) {
        assert cost = ns_mechs.STATIC_COST_SINGLETON;
    }
    return get_mechs_cost(mechs_len - 1, mechs + ns_mechs.INPUT_MECH_SIZE, sum + cost);
}

// @notice Iterates mechs and applies instructions
// @param board_dimension The dimensions of the board
// @param mechs The dictionary of mechs
// @param i The current mech index
// @param instructions The array of instructions for each mech
// @param atoms The dictionary of atoms on the board
// @param cost_increase The sum of increase in cost from mechs operations
// @return atoms_new The dictionary of updated atoms
// @return mechs_new The dictionary of updated mechs
// @return cost_increase The increase in cost from mechs operations
func iterate_mechs{range_check_ptr}(
    board_dimension: felt,
    mechs: DictAccess*,
    i: felt,
    instructions_len: felt,
    instructions: felt*,
    atoms: DictAccess*,
    cost_increase: felt,
) -> (atoms: DictAccess*, mechs: DictAccess*, cost_increase: felt) {
    alloc_locals;
    if (instructions_len == i) {
        return (atoms, mechs, cost_increase);
    }

    tempvar instruction = [instructions + i];
    let (ptr) = dict_read{dict_ptr=mechs}(key=i);
    tempvar mech = cast(ptr, MechState*);

    let can_move_right = is_le(mech.index.x, board_dimension - 2);
    if (instruction == ns_instructions.D and can_move_right == 1) {
        let (mechs_new) = update_mechs_moved(mech, mechs, 1, 0);
        let inc = get_cost_increase(mech.status);
        return iterate_mechs(
            board_dimension,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms,
            cost_increase + inc,
        );
    }
    let can_move_left = is_le(1, mech.index.x);
    if (instruction == ns_instructions.A and can_move_left == 1) {
        let (mechs_new) = update_mechs_moved(mech, mechs, -1, 0);
        let inc = get_cost_increase(mech.status);
        return iterate_mechs(
            board_dimension,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms,
            cost_increase + inc,
        );
    }
    let can_move_down = is_le(mech.index.y, board_dimension - 2);
    if (instruction == ns_instructions.S and can_move_down == 1) {
        let (mechs_new) = update_mechs_moved(mech, mechs, 0, 1);
        let inc = get_cost_increase(mech.status);
        return iterate_mechs(
            board_dimension,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms,
            cost_increase + inc,
        );
    }
    let can_move_up = is_le(1, mech.index.y);
    if (instruction == ns_instructions.W and can_move_up == 1) {
        let (mechs_new) = update_mechs_moved(mech, mechs, 0, -1);
        let inc = get_cost_increase(mech.status);
        return iterate_mechs(
            board_dimension,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms,
            cost_increase + inc,
        );
    }
    let (atoms_new, is_filled) = check_grid_filled(mech.index, atoms);
    if (instruction == ns_instructions.Z and mech.status == ns_mechs.OPEN and is_filled == 1) {
        let (atoms_new) = pick_up_atom(mech.id, mech.index, atoms_new);
        let (mechs_new) = update_mechs_status(mech, mechs, ns_mechs.CLOSE);
        return iterate_mechs(
            board_dimension,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_GET,
        );
    }
    let (atoms_new, is_free) = check_grid_free(mech.index, atoms_new);
    if (instruction == ns_instructions.X and mech.status == ns_mechs.CLOSE and is_free == 1) {
        let (atoms_new) = release_atom(mech.id, mech.index, atoms_new);
        let (mechs_new) = update_mechs_status(mech, mechs, ns_mechs.OPEN);
        return iterate_mechs(
            board_dimension,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_PUT,
        );
    }
    if (instruction == ns_instructions.G and mech.status == ns_mechs.OPEN and is_filled == 1) {
        let (atoms_new) = pick_up_atom(mech.id, mech.index, atoms_new);
        let (mechs_new) = update_mechs_status(mech, mechs, ns_mechs.CLOSE);
        return iterate_mechs(
            board_dimension,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_GET,
        );
    }
    if (instruction == ns_instructions.G and mech.status == ns_mechs.OPEN and is_filled == 0) {
        let (mechs_new) = update_mechs_pc(mech, mechs);
        return iterate_mechs(
            board_dimension,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_BLOCKED,
        );
    }
    if (instruction == ns_instructions.H and mech.status == ns_mechs.CLOSE and is_free == 1) {
        let (atoms_new) = release_atom(mech.id, mech.index, atoms_new);
        let (mechs_new) = update_mechs_status(mech, mechs, ns_mechs.OPEN);
        return iterate_mechs(
            board_dimension,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_PUT,
        );
    }
    if (instruction == ns_instructions.H and mech.status == ns_mechs.CLOSE and is_free == 0) {
        let (mechs_new) = update_mechs_pc(mech, mechs);
        return iterate_mechs(
            board_dimension,
            mechs_new,
            i + 1,
            instructions_len,
            instructions,
            atoms_new,
            cost_increase + ns_instructions_cost.SINGLETON_BLOCKED,
        );
    }
    return iterate_mechs(
        board_dimension, mechs, i + 1, instructions_len, instructions, atoms_new, cost_increase
    );
}

// @notice Updates the mechs dictionary after pc substraction
// @param mech The updated mech
// @param mechs The dictionary of mechs
// @return mechs_new The dictionary of updated mechs
func update_mechs_pc{range_check_ptr}(mech: MechState*, mechs: DictAccess*) -> (
    mechs_new: DictAccess*
) {
    tempvar mech_new: MechState* = new MechState(mech.id, mech.type, mech.status, Grid(mech.index.x, mech.index.y), mech.pc - 1);
    dict_write{dict_ptr=mechs}(key=mech.id, new_value=cast(mech_new, felt));
    return (mechs_new=mechs);
}

// @notice Updates the mechs dictionary after movement
// @param mech The updated mech
// @param mechs The dictionary of mechs
// @param x_inc The x position increase
// @param y_inc The y position increase
// @return mechs_new The dictionary of updated mechs
func update_mechs_moved{range_check_ptr}(
    mech: MechState*, mechs: DictAccess*, x_inc: felt, y_inc: felt
) -> (mechs_new: DictAccess*) {
    tempvar mech_new: MechState* = new MechState(mech.id, mech.type, mech.status, Grid(mech.index.x + x_inc, mech.index.y + y_inc), mech.pc);
    dict_write{dict_ptr=mechs}(key=mech.id, new_value=cast(mech_new, felt));
    return (mechs_new=mechs);
}

// @notice Updates the mechs dictionary after status update
// @param mech The updated mech
// @param mechs The dictionary of mechs
// @param status The new mech status
// @return mechs_new The dictionary of updated mechs
func update_mechs_status{range_check_ptr}(mech: MechState*, mechs: DictAccess*, status: felt) -> (
    mechs_new: DictAccess*
) {
    tempvar mech_new: MechState* = new MechState(mech.id, mech.type, status, Grid(mech.index.x, mech.index.y), mech.pc);
    dict_write{dict_ptr=mechs}(key=mech.id, new_value=cast(mech_new, felt));
    return (mechs_new=mechs);
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
