%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

from contracts.simulator.constants import ns_grid, ns_operators, ns_atoms
from contracts.simulator.grid import Grid, GRID_SIZE
from contracts.simulator.atoms import AtomState
from contracts.simulator.grid import check_position

struct OperatorType {
    input_atoms_len: felt,
    input_atoms: felt*,
    ouput_atoms_len: felt,
    ouput_atoms: felt*,
}

struct Operator {
    input_len: felt,
    input: Grid*,
    input_atom_types: felt*,
    output_len: felt,
    output: Grid*,
    type: OperatorType,
}

// @notice Verifies all operators are valid following 3 rules: 1. no overlap between operators
// @notice 2. all operators are within bounds 3. for a given operator, inputs and outputs should be continuous
// @param operators_type The array of types for each operator
// @param operator_input The array of positions for each input operator
// @param operator_output The array of positions for each output operator
func verify_valid{range_check_ptr}(
    operators_type_len: felt, operators_type: felt*, operator_input: Grid*, operator_output: Grid*
) {
    alloc_locals;
    if (operators_type_len == 0) {
        return ();
    }
    // TODO not effective to copy every time
    tempvar operator_type = [operators_type];
    let (input_offset, output_offset) = get_operator_lengths(operator_type);
    let (arr: felt*) = alloc();
    tempvar length_input = input_offset * GRID_SIZE;
    tempvar length_output = output_offset * GRID_SIZE;
    memcpy(arr, operator_input, length_input);
    memcpy(arr + length_input, operator_output, length_output);
    verify_valid_operator(input_offset + output_offset - 1, arr);

    return verify_valid(
        operators_type_len - 1,
        operators_type + 1,
        operator_input + length_input,
        operator_output + length_output,
    );
}

// @notice Verifies one operator is valid
// @param len The length of the operator array
// @param operator The array of operators
func verify_valid_operator{range_check_ptr}(len: felt, operator: felt*) {
    if (len == 0) {
        return ();
    }
    let grid_1 = Grid([operator], [operator + 1]);
    let grid_2 = Grid([operator + GRID_SIZE], [operator + GRID_SIZE + 1]);
    let (diff) = ns_grid.diff(grid_1, grid_2);
    tempvar sum = diff.x + diff.y;
    assert sum = 1;
    verify_valid_operator(len - 1, operator + GRID_SIZE);
    return ();
}

// @notice Iterates and applies operators
// @param atoms The array of atoms on the board
// @param operator_inputs The array of positions for input operators
// @param operator_outputs The array of positions for output operators
// @param operator_type The array of types for operator
// @return atoms_len_new The length of updated atoms
// @return atoms_new The array of updated atoms
func iterate_operators{syscall_ptr: felt*, range_check_ptr}(
    atoms_len: felt,
    atoms: AtomState*,
    operator_inputs: Grid*,
    operator_outputs: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
) -> (atoms_new_len: felt, atoms_new: AtomState*) {
    alloc_locals;
    if (operators_type_len == 0) {
        return (atoms_len, atoms);
    }
    tempvar operator_type = [operators_type];
    let (local input_length, output_length) = get_operator_lengths(operator_type);

    let is_valid_operation = check_operators(
        atoms_len,
        atoms,
        input_length,
        operator_inputs,
        output_length,
        operator_outputs,
        operator_type,
        0,
    );

    local atoms_new_len: felt;
    local atoms_new: AtomState*;
    if (is_valid_operation == 1) {
        let (a_new_1) = set_atoms_consumed(atoms_len, atoms, 0, input_length, operator_inputs);
        set_atoms_output(
            atoms_len - input_length, a_new_1, 0, output_length, operator_outputs, operator_type
        );
        assert atoms_new_len = atoms_len + output_length - input_length;
        assert atoms_new = a_new_1;
        tempvar range_check_ptr = range_check_ptr;
        tempvar syscall_ptr = syscall_ptr;
    } else {
        assert atoms_new_len = atoms_len;
        assert atoms_new = atoms;
        tempvar range_check_ptr = range_check_ptr;
        tempvar syscall_ptr = syscall_ptr;
    }
    return iterate_operators(
        atoms_new_len,
        atoms_new,
        operator_inputs + input_length * GRID_SIZE,
        operator_outputs + output_length * GRID_SIZE,
        operators_type_len - 1,
        operators_type + 1,
    );
}

// @notice Checks an operator can be applied i.e. inputs are correctly filled and outputs are empty
// @param atoms The array of atoms on the board
// @param operator_inputs The array of positions for input operators
// @param operator_outputs The array of positions for output operators
// @param operator_type The type for the operator
// @param filled The amount of filled inputs
// @return 1 if operator can be applied, 0 otherwise
func check_operators{syscall_ptr: felt*, range_check_ptr}(
    atoms_len: felt,
    atoms: AtomState*,
    operator_inputs_len: felt,
    operator_inputs: Grid*,
    operator_outputs_len: felt,
    operator_outputs: Grid*,
    operator_type: felt,
    filled: felt,
) -> felt {
    alloc_locals;
    if (atoms_len == 0) {
        if (operator_inputs_len == filled) {
            return 1;
        } else {
            return 0;
        }
    }
    tempvar atom = [atoms];
    let (local is_at_position_input, index) = check_position(
        atom.index, 0, operator_inputs_len, operator_inputs
    );
    let (local is_at_position_output, _) = check_position(
        atom.index, 0, operator_outputs_len, operator_outputs
    );
    let flavor = get_input_flavor(operator_type, index);
    if (is_at_position_input == 1 and flavor == atom.type and atom.status == ns_atoms.FREE) {
        return check_operators(
            atoms_len - 1,
            atoms + ns_atoms.ATOM_STATE_SIZE,
            operator_inputs_len,
            operator_inputs,
            operator_outputs_len,
            operator_outputs,
            operator_type,
            filled + 1,
        );
    }
    if (is_at_position_output == 1 and atom.status == ns_atoms.FREE) {
        return 0;
    }
    return check_operators(
        atoms_len - 1,
        atoms + ns_atoms.ATOM_STATE_SIZE,
        operator_inputs_len,
        operator_inputs,
        operator_outputs_len,
        operator_outputs,
        operator_type,
        filled,
    );
}

// @notice Sets the consumed atoms by deleting them
// @param atoms The array of atoms on the board
// @param operator_inputs The array of positions for input operators
// @param operator_type The type for the operator
// @return atoms_new The array of updated atoms
func set_atoms_consumed{syscall_ptr: felt*, range_check_ptr}(
    atoms_len: felt, atoms: AtomState*, i: felt, operator_input_len: felt, operator_input: Grid*
) -> (atoms_new: AtomState*) {
    alloc_locals;
    if (i == atoms_len) {
        return (atoms_new=atoms);
    }
    let atom = [atoms + i * ns_atoms.ATOM_STATE_SIZE];
    let (is_at_position, _) = check_position(atom.index, 0, operator_input_len, operator_input);
    if (is_at_position == 1 and atom.status == ns_atoms.FREE) {
        // TODO make a generic copy functin which takes i, atoms and AtomState and returns atoms_new
        let (atoms_new: AtomState*) = alloc();
        tempvar len_1 = i * ns_atoms.ATOM_STATE_SIZE;
        tempvar len_2 = (atoms_len - i - 1) * ns_atoms.ATOM_STATE_SIZE;
        memcpy(atoms_new, atoms, len_1);
        memcpy(atoms_new + len_1, atoms + len_1 + ns_atoms.ATOM_STATE_SIZE, len_2);
        return set_atoms_consumed(atoms_len - 1, atoms_new, i, operator_input_len, operator_input);
    }
    return set_atoms_consumed(atoms_len, atoms, i + 1, operator_input_len, operator_input);
}

// @notice Sets the produced atoms
// @param atoms The array of atoms on the board
// @param i The current index
// @param operator_outputs The array of positions for output operators
// @param operator_type The type for the operator
func set_atoms_output{}(
    atoms_len: felt,
    atoms: AtomState*,
    i: felt,
    operator_outputs_length: felt,
    operator_outputs: Grid*,
    operator_type: felt,
) {
    if (i == operator_outputs_length) {
        return ();
    }
    let flavor = get_output_flavor(operator_type, i);
    assert [atoms + atoms_len * ns_atoms.ATOM_STATE_SIZE] = AtomState(atoms_len, flavor, ns_atoms.FREE, [operator_outputs + i * GRID_SIZE], 0);
    return set_atoms_output(
        atoms_len + 1, atoms, i + 1, operator_outputs_length, operator_outputs, operator_type
    );
}

// @notice Returns the input and output length for a given operator
// @param operator The operator type
// @return input The input length of the operator
// @return output The output length of the operator
func get_operator_lengths{}(operator: felt) -> (input: felt, output: felt) {
    if (operator == ns_operators.STIR) {
        return (input=2, output=1);
    }
    if (operator == ns_operators.SHAKE) {
        return (input=2, output=1);
    }
    if (operator == ns_operators.STEAM) {
        return (input=3, output=2);
    }
    if (operator == ns_operators.SMASH) {
        return (input=1, output=5);
    }
    with_attr error_message("unknow operator") {
        assert 0 = 1;
    }
    return (input=0, output=0);
}

// @notice Returns the cost for the operators
// @param operators_type The array of types for the operators
// @param sum The sum of cost for the operators
// @return The sum of cost for the operators
func get_operators_cost{range_check_ptr}(
    operators_type_len: felt, operators_type: felt*, sum: felt
) -> felt {
    if (operators_type_len == 0) {
        return sum;
    }
    tempvar cost;
    tempvar operator_type = [operators_type];
    if (operator_type == ns_operators.STIR) {
        assert cost = ns_operators.STATIC_COST_STIR;
    }
    if (operator_type == ns_operators.SHAKE) {
        assert cost = ns_operators.STATIC_COST_SHAKE;
    }
    if (operator_type == ns_operators.STEAM) {
        assert cost = ns_operators.STATIC_COST_STEAM;
    }
    if (operator_type == ns_operators.SMASH) {
        assert cost = ns_operators.STATIC_COST_SMASH;
    }
    return get_operators_cost(operators_type_len - 1, operators_type + 1, sum + cost);
}

// @notice Returns the input flavor at index  for a operator type
// @param operator_type The type of the operator
// @param index The index for the input flavor
// @return The input flavor
func get_input_flavor{}(operator_type: felt, index: felt) -> felt {
    if (operator_type == ns_operators.STIR) {
        return ns_atoms.VANILLA;
    }
    if (operator_type == ns_operators.SHAKE) {
        return ns_atoms.HAZELNUT;
    }
    if (operator_type == ns_operators.STEAM) {
        if (index == 0) {
            return ns_atoms.HAZELNUT;
        } else {
            return ns_atoms.CHOCOLATE;
        }
    }
    if (operator_type == ns_operators.SMASH) {
        return ns_atoms.TRUFFLE;
    }
    with_attr error_message("incorrect operator") {
        assert 0 = 1;
    }
    return 0;
}

// @notice Returns the output flavor at index for a operator type
// @param operator_type The type of the operator
// @param index The index for the output flavor
// @return The output flavor
func get_output_flavor{}(operator_type: felt, index: felt) -> felt {
    if (operator_type == ns_operators.STIR) {
        return ns_atoms.HAZELNUT;
    }
    if (operator_type == ns_operators.SHAKE) {
        return ns_atoms.CHOCOLATE;
    }
    if (operator_type == ns_operators.STEAM) {
        if (index == 0) {
            return ns_atoms.TRUFFLE;
        } else {
            return ns_atoms.VANILLA;
        }
    }
    if (operator_type == ns_operators.SMASH) {
        if (index == 4) {
            return ns_atoms.SAFFRON;
        } else {
            return ns_atoms.VANILLA;
        }
    }
    with_attr error_message("incorrect operator") {
        assert 0 = 1;
    }
    return 0;
}
