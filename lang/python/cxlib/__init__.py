from .cx import (
    version, abi_version, features,
    to_cx,   to_cx_compact,   to_xml,   to_ast,   to_json,   to_yaml,   to_toml,
    ast_to_cx,
    xml_to_cx,  xml_to_xml,  xml_to_ast,  xml_to_json,  xml_to_yaml,  xml_to_toml,
    json_to_cx, json_to_xml, json_to_ast, json_to_json, json_to_yaml, json_to_toml,
    yaml_to_cx, yaml_to_xml, yaml_to_ast, yaml_to_json, yaml_to_yaml, yaml_to_toml,
    toml_to_cx, toml_to_xml, toml_to_ast, toml_to_json, toml_to_yaml, toml_to_toml,
    to_data_bin, from_data_bin,
    xml_to_data_bin, json_to_data_bin, yaml_to_data_bin, toml_to_data_bin,
    data_bin_to_xml, data_bin_to_json, data_bin_to_yaml, data_bin_to_toml,
    to_delimited, from_delimited,
    to_csv, from_csv, to_tsv, from_tsv, to_psv, from_psv,
    csv_to_data_bin, tsv_to_data_bin, psv_to_data_bin,
    data_bin_to_csv, data_bin_to_tsv, data_bin_to_psv,
    to_data_bin_chunked,
    to_data_bin_schema_driven, xml_to_data_bin_schema_driven,
    json_to_data_bin_schema_driven, yaml_to_data_bin_schema_driven,
    toml_to_data_bin_schema_driven,
    csv_to_data_bin_schema_driven, tsv_to_data_bin_schema_driven,
    psv_to_data_bin_schema_driven, from_data_bin_schema_driven,
    eval_code, eval_code_streaming,
)
from .binary import ast_bin as to_ast_bin
from .streaming_table import TableReader, TableWriter
from .table import Table
from .event_writer import EventWriter
from .ast import (
    Attr, Atom, Text, Scalar, Comment, RawText, EntityRef, Alias,
    PI, XMLDecl, CXDirective, BlockContent, DoctypeDecl,
    Element, Document, Node,
    parse, parse_xml, parse_json, parse_yaml, parse_toml,
    loads, loads_xml, loads_json, loads_yaml, loads_toml, dumps,
    # atom Layer-1 surface (snake_case per spec/bindings.md).
    atom, is_atom, atom_name,
    # v0.8.0 collection value-kinds (ast_bin §4.3, tags 0x0F/0x10/0x11).
    SequenceNode, ArrayNode, MapNode, MapEntry,
    # Iterator value kind (W3f, v0.8.0).
    IteratorNode, iter_kind_name,
    ITER_NONE, ITER_RANGE, ITER_MAP, ITER_FILTER, ITER_TAKE, ITER_DROP,
    ITER_CONCAT, ITER_CHAIN, ITER_ZIP, ITER_ENUMERATE, ITER_CHUNKS,
    ITER_CYCLE, ITER_SCAN, ITER_FLATTEN, ITER_PARTITION, ITER_GROUP_BY,
    ITER_REDUCE,
)
from .stream import stream, Stream, StreamEvent
from .validate import (
    Severity, Diagnostic, ValidationReport,
    validate, validate_with_defaults,
)
# v0.8.0 Layer-1 surface (spec/bindings.md §2.1) — Doc / Node façade
# wrapping the 16-method canonical contract plus the 
# diagram / tree projections.  `cxlib.idioms` re-exports Doc with
# Pythonic dunder sugar on top.
from .code import (
    Doc, Node, parse as parse_doc,
    cx_code_eval, cx_code_diagram, cx_code_tree,
)
# CX-native conformance fixture loader (mirror of vcx/cx/fixture_loader.v).
from .fixtures import FixtureCase, load_fixtures, parse_fixture_suite
