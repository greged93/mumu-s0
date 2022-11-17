%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.dict_access import DictAccess

from contracts.simulator.constants import ns_grid, ns_operators, ns_atoms, ns_dict
from contracts.simulator.utils import check_uniqueness
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

// @notice Verifies all operators are valid following 3 rules: 1. no overlap between operators (including sinks and faucets)
// @notice 2. all operators are within bounds 3. for a given operator, inputs and outputs should be continuous
// @param piping The piping (sinks, faucets) for atoms
// @param atom_sinks The array of sinks for atoms
// @param operators_type The array of types for each operator
// @param operator_input The array of positions for each input operator
// @param operator_output The array of positions for each output operator
// @param dimension The dimension of the board
func verify_valid_operators{range_check_ptr}(
    piping_len: felt,
    piping: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
    operators_inputs_len: felt,
    operators_inputs: Grid*,
    operators_outputs_len: felt,
    operators_outputs: Grid*,
    dimension: felt,
) {
    alloc_locals;
    // Rule 1: Check for overlapping operators
    let (local dict) = default_dict_new(default_value=0);
    with_attr error_message("overlapping operators") {
        let (dict_) = check_uniqueness(operators_inputs_len, operators_inputs, dict);
        let (dict_) = check_uniqueness(operators_outputs_len, operators_outputs, dict_);
    }
    with_attr error_message("overlapping piping") {
        let (dict_) = check_uniqueness(piping_len, piping, dict_);
    }
    default_dict_finalize(dict_accesses_start=dict_, dict_accesses_end=dict_, default_value=0);
    // Rule 2: Check the operators are within bounds
    verify_bounded_operators(operators_inputs_len, operators_inputs, dimension);
    verify_bounded_operators(operators_outputs_len, operators_outputs, dimension);
    // Rule 3: Check the operators are continuous and total length match
    verify_continuous_operators(
        operators_type_len,
        operators_type,
        operators_inputs,
        operators_outputs,
        operators_inputs_len + operators_outputs_len,
        0,
    );
    return ();
}

// @notice Verifies all operators are within the board's bounds
// @param operators The positions of operators on the grid
// @param dimension The dimensions of the board
func verify_bounded_operators{range_check_ptr}(
    operators_len: felt, operators: Grid*, dimension: felt
) {
    if (operators_len == 0) {
        return ();
    }
    tempvar operator = [operators];
    with_attr error_message("operator not within bounds") {
        assert [range_check_ptr] = dimension - operator.x - 1;
        assert [range_check_ptr + 1] = dimension - operator.y - 1;
    }
    let range_check_ptr = range_check_ptr + 2;
    return verify_bounded_operators(operators_len - 1, operators + GRID_SIZE, dimension);
}

// @notice Verifies all operators are continuous following rule 3
// @param operators_type The array of types for each operator
// @param operator_input The array of positions for each input operator
// @param operator_output The array of positions for each output operator
func verify_continuous_operators{range_check_ptr}(
    operators_type_len: felt,
    operators_type: felt*,
    operators_inputs: Grid*,
    operators_outputs: Grid*,
    expected_sum: felt,
    sum: felt,
) {
    alloc_locals;
    if (operators_type_len == 0) {
        with_attr error_message("mismatched operators type") {
            assert expected_sum = sum;
        }
        return ();
    }
    tempvar operator_type = [operators_type];
    let (input_offset, output_offset) = get_operator_lengths(operator_type);
    let (arr: felt*) = alloc();
    tempvar length_input = input_offset * GRID_SIZE;
    tempvar length_output = output_offset * GRID_SIZE;
    memcpy(arr, operators_inputs, length_input);
    memcpy(arr + length_input, operators_outputs, length_output);
    verify_continuous_operator(input_offset + output_offset - 1, arr);

    return verify_continuous_operators(
        operators_type_len - 1,
        operators_type + 1,
        operators_inputs + length_input,
        operators_outputs + length_output,
        expected_sum,
        sum + input_offset + output_offset,
    );
}

// @notice Verifies one operator is continuous following rule 3
// @param len The length of the operator array
// @param operator The array of operators
func verify_continuous_operator{range_check_ptr}(len: felt, operator: felt*) {
    if (len == 0) {
        return ();
    }
    let grid_1 = Grid([operator], [operator + 1]);
    let grid_2 = Grid([operator + GRID_SIZE], [operator + GRID_SIZE + 1]);
    let (diff) = ns_grid.diff(grid_1, grid_2);
    tempvar sum = diff.x + diff.y;
    with_attr error_message("operator continuity error") {
        assert sum = 1;
    }
    verify_continuous_operator(len - 1, operator + GRID_SIZE);
    return ();
}

// @notice Iterates and applies operators
// @param atoms The dictionary of atoms on the board
// @param operator_inputs The array of positions for input operators
// @param operator_outputs The array of positions for output operators
// @param operator_type The array of types for operator
// @return atoms_len_new The length of updated atoms
// @return atoms_new The dictionary of updated atoms
func iterate_operators{range_check_ptr}(
    atoms: DictAccess*,
    operator_inputs: Grid*,
    operator_outputs: Grid*,
    operators_type_len: felt,
    operators_type: felt*,
) -> (atoms_new: DictAccess*) {
    alloc_locals;
    if (operators_type_len == 0) {
        return (atoms_new=atoms);
    }
    tempvar operator_type = [operators_type];
    let (local input_length, output_length) = get_operator_lengths(operator_type);

    let (_atoms, is_input_operation_valid) = check_operators_input(
        atoms, input_length, operator_inputs, 0, operator_type
    );
    let (_atoms, is_output_operation_valid) = check_operators_output(
        _atoms, output_length, operator_outputs
    );

    local atoms_new: DictAccess*;
    if (is_input_operation_valid + is_output_operation_valid == 2) {
        let (a_new_1) = set_atoms_consumed(_atoms, input_length, operator_inputs);
        let (a_new_2) = set_atoms_output(
            a_new_1, 0, output_length, operator_outputs, operator_type
        );
        assert atoms_new = a_new_2;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        assert atoms_new = _atoms;
        tempvar range_check_ptr = range_check_ptr;
    }
    return iterate_operators(
        atoms_new,
        operator_inputs + input_length * GRID_SIZE,
        operator_outputs + output_length * GRID_SIZE,
        operators_type_len - 1,
        operators_type + 1,
    );
}

// @notice Checks an operator's input are valid i.e. inputs are correctly filled
// @param atoms The dictionary of atoms on the board
// @param operator_inputs The array of positions for input operators
// @param operator_type The type for the operator
// @return 1 if operator can be applied, 0 otherwise
func check_operators_input{range_check_ptr}(
    atoms: DictAccess*,
    operator_inputs_len: felt,
    operator_inputs: Grid*,
    i: felt,
    operator_type: felt,
) -> (atoms_new: DictAccess*, is_input_filled: felt) {
    alloc_locals;
    if (operator_inputs_len == 0) {
        return (atoms_new=atoms, is_input_filled=1);
    }
    tempvar operator = [operator_inputs];
    tempvar key = operator.x * ns_dict.MULTIPLIER + operator.y;
    let (local ptr) = dict_read{dict_ptr=atoms}(key=key);
    let flavor = get_input_flavor(operator_type, i);
    if (ptr == 0) {
        return (atoms_new=atoms, is_input_filled=0);
    }
    tempvar atom = cast(ptr, AtomState*);
    if (flavor == atom.type) {
        return check_operators_input(
            atoms, operator_inputs_len - 1, operator_inputs + GRID_SIZE, i + 1, operator_type
        );
    }
    return (atoms_new=atoms, is_input_filled=0);
}

// @notice Checks an operator's output are valid i.e. outputs are empty
// @param atoms The dictionary of atoms on the board
// @param operator_outputs The array of positions for output operators
// @return 1 if operator can be applied, 0 otherwise
func check_operators_output{range_check_ptr}(
    atoms: DictAccess*, operator_outputs_len: felt, operator_outputs: Grid*
) -> (atoms_new: DictAccess*, is_output_free: felt) {
    if (operator_outputs_len == 0) {
        return (atoms_new=atoms, is_output_free=1);
    }
    tempvar operator = [operator_outputs];
    tempvar key = operator.x * ns_dict.MULTIPLIER + operator.y;
    let (ptr) = dict_read{dict_ptr=atoms}(key=key);
    if (ptr == 0) {
        return check_operators_output(
            atoms, operator_outputs_len - 1, operator_outputs + GRID_SIZE
        );
    }
    return (atoms_new=atoms, is_output_free=0);
}

// @notice Sets the consumed atoms by deleting them
// @param atoms The dictionary of atoms on the board
// @param operator_inputs The array of positions for input operators
// @return atoms_new The dictionary of updated atoms
func set_atoms_consumed{range_check_ptr}(
    atoms: DictAccess*, operator_input_len: felt, operator_inputs: Grid*
) -> (atoms_new: DictAccess*) {
    alloc_locals;
    if (operator_input_len == 0) {
        return (atoms_new=atoms);
    }
    tempvar operator = [operator_inputs];
    tempvar key = operator.x * ns_dict.MULTIPLIER + operator.y;
    dict_write{dict_ptr=atoms}(key=key, new_value=0);
    return set_atoms_consumed(atoms, operator_input_len - 1, operator_inputs + GRID_SIZE);
}

// @notice Sets the produced atoms
// @param atoms The dictionary of atoms on the board
// @param operator_outputs The array of positions for output operators
// @param operator_type The type for the operator
// @return atoms_new The new dictionary of atoms
func set_atoms_output{}(
    atoms: DictAccess*,
    i: felt,
    operator_outputs_length: felt,
    operator_outputs: Grid*,
    operator_type: felt,
) -> (atoms_new: DictAccess*) {
    if (i == operator_outputs_length) {
        return (atoms_new=atoms);
    }
    let flavor = get_output_flavor(operator_type, i);
    tempvar operator = [operator_outputs + i * GRID_SIZE];

    tempvar key = operator.x * ns_dict.MULTIPLIER + operator.y;
    tempvar atom_new: AtomState* = new AtomState(
        flavor, ns_atoms.FREE, operator, 0
        );
    dict_write{dict_ptr=atoms}(key=key, new_value=cast(atom_new, felt));

    return set_atoms_output(atoms, i + 1, operator_outputs_length, operator_outputs, operator_type);
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
