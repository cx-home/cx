# frozen_string_literal: true

# CX Ruby binding — Public Table API per ADR 0018 D1.
#
# 17-member canonical Table surface against the V core's :table blocks
# via the C ABI. Per ADR 0018 §D2: Ruby uses snake_case methods matching
# the canonical surface (rename `select` → `select_cols` to avoid
# clobbering Enumerable#select via include).

require 'json'

module CXLib
  class Table
    include Enumerable

    # ── Construction ───────────────────────────────────────────────────────

    # Parse CX source and return the first :table block.
    def self.from_cx(src)
      tables = from_cx_all(src)
      raise "cxlib: no :table block found in source" if tables.empty?
      tables.first
    end

    # Return every :table block in the source (preorder).
    def self.from_cx_all(src)
      payload = CXLib.to_data_bin(src)
      decoded = CXLib::DataBin.decode(payload)
      out = []
      _collect_tables(decoded, out)
      out
    end

    # Direct construction with 4-invariant validation per ADR 0018 §D7.
    def self.create(cols, types, rows)
      raise "cxlib: len(cols)=#{cols.size} != len(types)=#{types.size}" if cols.size != types.size
      seen = {}
      cols.each do |c|
        raise "cxlib: duplicate column name \"#{c}\"" if seen.key?(c)
        seen[c] = true
      end
      rows.each_with_index do |row, i|
        raise "cxlib: row #{i} has #{row.size} cells; expected #{cols.size}" if row.size != cols.size
      end
      allocate.tap { |t| t.send(:_init, cols.dup, types.dup, rows.map(&:dup)) }
    end

    def initialize(cols, types, rows)
      _init(cols, types, rows)
    end

    # ── Properties (4) ─────────────────────────────────────────────────────

    def cols      = @cols.dup
    def types     = @types.dup
    def row_count = @rows.size
    def col_count = @cols.size

    # ── Access (9) ─────────────────────────────────────────────────────────

    def row(i)
      raise "cxlib: row index #{i} out of bounds [0, #{@rows.size})" unless i.between?(0, @rows.size - 1)
      h = {}
      @cols.each_with_index { |name, c| h[name] = @rows[i][c] }
      h
    end

    def column(name)
      idx = @cols.index(name)
      raise "cxlib: unknown column \"#{name}\"" unless idx
      col_at(idx)
    end

    def col_at(i)
      raise "cxlib: column index #{i} out of bounds [0, #{@cols.size})" unless i.between?(0, @cols.size - 1)
      @rows.map { |row| row[i] }
    end

    def cell(r, c)
      raise "cxlib: row index #{r} out of bounds [0, #{@rows.size})" unless r.between?(0, @rows.size - 1)
      raise "cxlib: column index #{c} out of bounds [0, #{@cols.size})" unless c.between?(0, @cols.size - 1)
      @rows[r][c]
    end

    def cell_by_name(r, name)
      idx = @cols.index(name)
      raise "cxlib: unknown column \"#{name}\"" unless idx
      cell(r, idx)
    end

    def slice(start_idx, end_idx)
      raise "cxlib: slice start #{start_idx} out of bounds" unless start_idx.between?(0, @rows.size)
      raise "cxlib: slice end #{end_idx} out of bounds (start=#{start_idx})" unless end_idx.between?(start_idx, @rows.size)
      Table.create(@cols, @types, @rows[start_idx...end_idx].map(&:dup))
    end

    def head(n)
      slice(0, [[n, 0].max, @rows.size].min)
    end

    def tail(n)
      start_idx = [0, @rows.size - n].max
      slice(start_idx, @rows.size)
    end

    # `select_cols` — renamed from canonical `select` (Ruby's
    # Enumerable#select via `include` would clobber it).
    def select_cols(names)
      indices = names.map do |n|
        idx = @cols.index(n)
        raise "cxlib: unknown column \"#{n}\"" unless idx
        idx
      end
      new_cols  = indices.map { |i| @cols[i] }
      new_types = indices.map { |i| @types[i] }
      new_rows  = @rows.map { |row| indices.map { |i| row[i] } }
      Table.create(new_cols, new_types, new_rows)
    end

    # ── Iteration (2) ──────────────────────────────────────────────────────

    def each
      return enum_for(:each) unless block_given?
      (0...@rows.size).each { |i| yield row(i) }
    end

    def iter_cols
      return enum_for(:iter_cols) unless block_given?
      @cols.each_with_index do |name, i|
        yield ColumnView.new(name, @types[i], col_at(i))
      end
    end

    # ── Conversion (5) ─────────────────────────────────────────────────────

    def to_cx
      header = @cols.each_with_index.map { |c, i| @types[i].empty? ? c : "#{c}:#{@types[i]}" }.join(' ')
      lines = ["[_ :table[#{header}]"]
      @rows.each do |row|
        lines << '  ' + row.map { |v| Table._format_cx_cell(v) }.join(' ')
      end
      lines << ']'
      lines.join("\n") + "\n"
    end

    def to_csv(delim: ',')
      raise "cxlib: to_csv delim must be 1 char; got #{delim.size}" if delim.size != 1
      lines = [@cols.join(delim)]
      @rows.each do |row|
        lines << row.map { |v| Table._format_csv_cell(v, delim) }.join(delim)
      end
      lines.join("\r\n") + "\r\n"
    end

    def to_json(*_args)
      JSON.generate(to_dict_list)
    end

    def to_data_bin
      CXLib.to_data_bin(to_cx)
    end

    def to_dict_list
      (0...@rows.size).map { |i| row(i) }
    end

    # ── Equality ───────────────────────────────────────────────────────────

    def ==(other)
      return false unless other.is_a?(Table)
      @cols == other.cols && @types == other.types && @rows == other.instance_variable_get(:@rows)
    end
    alias eql? ==

    def hash
      [@cols, @types, @rows.size].hash
    end

    # ── Internal: walk decoded data_bin value to find tables ───────────────

    def self._collect_tables(value, out)
      case value
      when nil
        nil
      when Hash
        value.each_value { |child| _collect_tables(child, out) }
      when Array
        if _looks_like_table(value)
          first = value.first
          keys = first.keys.sort
          types = keys.map { '' }
          rows = value.map { |item| keys.map { |k| item[k] } }
          out << create(keys, types, rows)
        else
          value.each { |child| _collect_tables(child, out) }
        end
      end
    end

    def self._looks_like_table(arr)
      return false if arr.empty?
      first = arr.first
      return false unless first.is_a?(Hash)
      keys = first.keys
      return false if keys.empty?
      key_set = keys.to_set
      arr.all? do |item|
        item.is_a?(Hash) && item.size == keys.size && item.keys.all? { |k| key_set.include?(k) }
      end
    end

    def self._format_cx_cell(v)
      case v
      when nil then 'null'
      when true then 'true'
      when false then 'false'
      when Integer, Float then v.to_s
      when Array then '[' + v.map { |x| _format_cx_cell(x) }.join(', ') + ']'
      when Hash
        keys = v.keys.sort
        '{' + keys.map { |k| "#{_format_cx_key(k)}: #{_format_cx_cell(v[k])}" }.join(', ') + '}'
      else
        s = v.to_s
        if s.empty? || s =~ /[\s'\[\](){},]/
          "'" + s.gsub("'", "''") + "'"
        else
          s
        end
      end
    end

    def self._format_cx_key(k)
      return k if k =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/
      "'" + k.gsub("'", "''") + "'"
    end

    def self._format_csv_cell(v, delim)
      return '' if v.nil?
      return '"' + JSON.generate(v).gsub('"', '""') + '"' if v.is_a?(Hash) || v.is_a?(Array)
      return v ? 'true' : 'false' if v == true || v == false
      s = v.to_s
      if s.include?(delim) || s.include?('"') || s.include?("\n") || s.include?("\r")
        '"' + s.gsub('"', '""') + '"'
      else
        s
      end
    end

    private

    def _init(cols, types, rows)
      @cols = cols
      @types = types
      @rows = rows
    end
  end

  # Column iterator view.
  ColumnView = Struct.new(:name, :type_name, :values)
end

require 'set'
