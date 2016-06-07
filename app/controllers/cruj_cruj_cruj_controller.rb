class CrujCrujCrujController < ApplicationController
  include ActionView::Helpers::NumberHelper

  before_filter :before_index , only: [:index]
  before_filter :before_new   , only: [:new]
  before_filter :before_create, only: [:create]
  before_filter :before_edit  , only: [:edit]
  before_filter :before_update, only: [:update]
  before_filter :before_destroy, only: [:destroy]

  before_filter :find_all_resources, only: [:index]
  before_filter :build_resource    , only: [:new, :create]
  before_filter :find_resource     , only: [:edit, :update, :destroy]

  helper_method :namespace_url, :namespaces, :model_class, :snake_case_model_name,
                :resource_url,
                :index_attributes, :exclude_index_attributes,
                :index_filter_attributes, :exclude_index_filter_attributes,
                :associations_names, :format_field,
                :filter_for

  def index; end
  def new; end

  def create
    if @resource.save
      redirect_to(action: :index, notice: l("#{snake_case_model_name}_create_success_message"))
    else
      render action: 'new'
    end
  end

  def edit; end

  def update
    if @resource.update_attributes(params[snake_case_model_name])
      redirect_to(action: :index, notice: l("#{snake_case_model_name}_edit_success_message"))
    else
      render action: 'edit'
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def destroy
    @resource.destroy
    redirect_to action: :index, notice: l("#{snake_case_model_name}_delete_success_message")
  end

  def export_template
    @q = model_class.ransack(params[:q])
    @q.sorts = default_sort if @q.sorts.blank?

    filename = CrujCrujCruj::Services::ImportRules.export_template(form_fields, @q.result)
    send_file(filename, filename: l(:export_template_filename), type: "application/vnd.ms-excel")
  end

  def import
    if params[:file].blank?
      redirect_to url_for(action: :index, controller: params[:controller]), {flash: {error: l(:no_file_to_import_error_message)}}
      return
    end

    errors = CrujCrujCruj::Services::ImportRules.import(params[:file], form_fields, model_class)

    if errors.blank?
      redirect_to url_for(action: :index, controller: params[:controller]), notice: l(:import_success_message)
      return
    end
    redirect_to url_for(action: :index, controller: params[:controller]), flash: { import_errors: errors.join('<br />') }
  end

  protected

  def before_index; end
  def before_new; end
  def before_create; end
  def before_edit; end
  def before_update; end
  def before_destroy; end

  def find_all_resources
    @q = model_class.ransack(params[:q])
    @q.sorts = default_sort if @q.sorts.blank?
    @resources = @q.result.page(params[:page])
  end

  def build_resource
    @resource = model_class.new(params[snake_case_model_name])
  end

  def find_resource
    @resource = model_class.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def form_fields
    []
  end

  def namespace_url
    []
  end

  def namespaces
    params[:controller].split('/')[0..-2]
  end

  def model_name
    self.class.name.sub(/Controller$/, '').singularize
  end

  def model_class
    model_name.constantize
  end

  def snake_case_model_name
    model_name.split('::')[-1].gsub(/(.)([A-Z])/, '\1_\2').downcase.to_sym
  end

  def resource_url(resource)
    if Rails::VERSION::MAJOR >= 4
      namespace_url + [resource] + [ resource.respond_to?(:type) ? {"type" => resource.type} : {} ]
    else
      namespace_url + [resource]
    end
  end

  def index_attributes
    @index_attributes ||= associations_names(:belongs_to) | model_class.attribute_names
  end

  def exclude_index_attributes
    %w(^id$ _id created_at updated_at)
  end

  def index_filter_attributes
    index_attributes.map { |ia| filter_for(ia) }
  end

  def default_sort
    index_filter_attributes.map { |ifa| ifa.is_a?(Array) ? "#{ifa[0].split('_')[0..-2].join("_")} asc" : "#{ifa.split('_')[0..-2].join("_")} asc" }
  end

  def exclude_index_filter_attributes
    exclude_index_attributes
  end

  def associations_names(association)
    model_class.reflect_on_all_associations(association).reject { |value| value.options.key?(:through) }.map(&:name)
  end

  def format_field(field, possible_values)
    if possible_values.blank?
      send("format_field_#{field.class.name.downcase}", field)
    else
      possible_values[send("format_field_#{field.class.name.downcase}", field)]
    end
  rescue
    field.name
  end

  def format_field_nilclass(field)
    ''
  end

  def format_field_string(field)
    field
  end

  def format_field_trueclass(field)
    t(:true_field)
  end

  def format_field_falseclass(field)
    t(:false_field)
  end

  def format_field_fixnum(field)
    number_with_delimiter(field)
  end

  def format_field_float(field)
    number_with_precision(field)
  end

  def filter_for(attribute)
    if attribute.is_a? Array
      send("filter_for_enum", attribute[0], attribute[1])
    elsif column = model_class.columns_hash[attribute.to_s]
      send("filter_for_#{column.type}", attribute)
    else
      send("filter_for_#{attribute}")
    end
  rescue
    "#{attribute}_cont"
  end

  def filter_for_boolean(attribute)
    "#{attribute}_true"
  end

  def filter_for_project
    "project_name_cont"
  end

  def filter_for_tracker
    "tracker_name_cont"
  end

  def filter_for_group
    "group_lastname_cont"
  end

  def filter_for_status
    "status_name_cont"
  end

  def filter_for_issue_status
    "issue_status_name_cont"
  end

  def filter_for_status_to
    "status_to_name_cont"
  end

  def filter_for_status_from
    "status_from_name_cont"
  end

  def filter_for_custom_field
    "custom_field_name_cont"
  end

  def filter_for_author
    "author_firstname_or_author_lastname_cont"
  end

  def filter_for_principal
    "principal_firstname_or_principal_lastname_cont"
  end

  def filter_for_role
    "role_name_cont"
  end

  def filter_for_enum(attribute, values)
    ["#{attribute}_eq", values]
  end
end
