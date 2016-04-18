#encoding: utf-8
module CrujCrujCruj
  module Services
    class ImportRules

      def self.export_template(fields, data)
        package          = Axlsx::Package.new
        workbook         = package.workbook

        parameters_sheet_name = 'PARAMETERS'

        workbook.add_worksheet(name: 'TEMPLATE') do |sheet|
          title = sheet.styles.add_style(bg_color: 'FF007E7A', fg_color: 'FFFFFFFF', sz: 12,  b: true, border: {style: :thin, color: 'FF000000'})

          fields.each_with_index do |field, idx|
            validation  = field[:data_validation][:validation]
            allow_blank = field[:data_validation][:allow_blank]
            add_data_validation(sheet, idx + 1, validation, allow_blank, parameters_sheet_name) if validation
          end

          sheet.add_row (([:id] |fields.map { |field| field[:field_name] }).map { |t| I18n.t("#{t}_label") }), style: title

          data.map { |resource| [resource.id].concat(fields.map { |field| resource_field_value(resource, field) }) }.each do |row|
            sheet.add_row row, types: row.map{ |_| :string }
          end
        end

        create_validations(fields, workbook, parameters_sheet_name)

        filename = "tmp/template_#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.xlsx"
        package.serialize(filename)
        filename
      end

      def self.import(file, fields, clazz)
        spreadsheet = Roo::Spreadsheet.open(file.path, extension: :xlsx)

        errors = []

        invalid_rows = validate_id(spreadsheet, clazz)
        errors << I18n.t(:column_invalid_rows, column: :id, rows: invalid_rows.first(25).join(', ')) unless invalid_rows.blank?

        fields.each_with_index do |field, idx|
          col = idx + 1
          unless field[:data_validation][:allow_blank]
            invalid_rows = validate_not_blank(col, spreadsheet)
            errors << I18n.t(:column_invalid_rows, column: field[:field_name], rows: invalid_rows.first(25).join(', ')) unless invalid_rows.blank?
          end

          if field[:data_validation][:validation]
            invalid_rows = validate_in_array(col, field_validation_values(field), spreadsheet)
            errors << I18n.t(:column_invalid_rows, column: field[:field_name], rows: invalid_rows.first(25).join(', ')) unless invalid_rows.blank?
          end
        end

        return errors unless errors.blank?


        (2..spreadsheet.last_row).each do |i|
          row = spreadsheet.row(i)
          id  = row[0]
          resource = id ? clazz.find(id) : clazz.new

          fields.each_with_index do |field, idx|
            resource.send("#{field[:field_name]}=", row_value(row, idx+1, field, spreadsheet))
            resource.save!
          end
        end

        {}
      end

      protected


      def self.add_data_validation(sheet, column_number, validation, allowBlank, parameters_sheet_name)
        column_letter = number2column(column_number)
        values_size   = validation.is_a?(Array) ? validation.size : validation[:clazz].all.count
        sheet.add_data_validation("#{column_letter}2:#{column_letter}1048576", type: :list, allowBlank: allowBlank, formula1: "#{parameters_sheet_name}!$#{column_letter}$2:$#{column_letter}$#{values_size+1}")
      end

      def self.create_validations(fields, workbook, parameters_sheet_name)
        workbook.add_worksheet(name: parameters_sheet_name) do |sheet|
          sheet.add_row [:id] | fields.map { |field| field[:field_name] }

          cols_values = [[]].concat(fields.map { |field| field_validation_values(field) })

          cols_values.map { |values| values.size }.max.times do |i|
            row = cols_values.map { |v| v[i] }
            sheet.add_row row, types: row.map{ |_| :string }
          end
        end
      end

      def self.resource_field_value(resource, field)
        if field[:data_validation][:validation] && !field[:data_validation][:validation].is_a?(Array)
          relation = resource.send(field[:field_name])
          relation ? relation.send(field[:data_validation][:validation][:field]) : nil
        else
          resource.send(field[:field_name])
        end
      end

      def self.field_validation_values(field)
        if field[:data_validation][:validation]
          if field[:data_validation][:validation].is_a?(Array)
            field[:data_validation][:validation]
          else
            field[:data_validation][:validation][:clazz].all.order(field[:data_validation][:validation][:field]).pluck(field[:data_validation][:validation][:field])
          end
        else
          []
        end
      end

      def self.number2column(number)
        Hash.new {|hash,key| hash[key] = hash[key - 1].next }.merge({0 => "A"})[number]
      end

      def self.validate_id(spreadsheet, clazz)
        validate_in_array(0, clazz.all.pluck(:id).map(&:to_s), spreadsheet)
      end

      def self.validate_not_blank(col, spreadsheet)
        (2..spreadsheet.last_row)
          .map { |i| {i => !spreadsheet.row(i)[col].blank? } }
          .select { |e| !e.values.first }
          .map { |e| e.keys.first }
      end

      def self.validate_in_array(col, array, spreadsheet)
        (2..spreadsheet.last_row)
          .map { |i| { i => (spreadsheet.row(i)[col].blank? || array.map(&:to_s).map(&:downcase).include?(spreadsheet.row(i)[col].to_s.downcase)) } }
          .select { |e| !e.values.first }
          .map { |e| e.keys.first }
      end

      def self.fetch(row, col, spreadsheet)
        spreadsheet.celltype(row, col + 1) == :float ? spreadsheet.send(:cell_to_csv, row, col + 1, spreadsheet.default_sheet) : row[col]
      end

      def self.row_value(row, col, field, spreadsheet)
        if field[:data_validation][:validation] && !field[:data_validation][:validation].is_a?(Array)
          field[:data_validation][:validation][:clazz].send("find_by_#{field[:data_validation][:validation][:field]}", fetch(row, col, spreadsheet))
        else
          fetch(row, col, spreadsheet)
        end
      end
    end
  end
end
