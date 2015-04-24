class ObjectFactory

  attr_reader :attributes, :files_directory

  def initialize(attributes, files_dir=nil)
    @files_directory = files_dir
    @attributes = attributes
  end

  def run
    if obj = find
      update(obj)
    else
      obj = create
    end
    yield(obj) if block_given?
    obj
  end

  def update(obj)
    obj.attributes = transform_attributes.except(:id)
    obj.save!
    after_save(obj)
    puts "  Updated #{klass.to_s.downcase} #{obj.id} (#{attributes[:accession_number].first})"
  end

  # override after_save if you want to put something here.
  def after_save(obj)
  end

  # override after_create if you want to put something here.
  def after_create(obj)
  end

  def create_attributes
    transform_attributes
  end

  def find
    klass.find(attributes[:id]) if klass.exists?(attributes[:id])
  end

  def create
    attrs = create_attributes
    identifier = mint_ark
    attrs.merge!(identifier: [identifier.id], id: Identifier.treeify(identifier.id.split(/\//).last))
    klass.new(attrs) do |obj|
      obj.save!
      after_create(obj)
      after_save(obj)
      identifier.target = path_for(obj)
      identifier.save
      puts "  Created #{klass.to_s.downcase} #{obj.id} (#{attributes[:accession_number].first})"
    end
  end

  def klass
    raise "You must implement the klass method"
  end

  # @return [Ezid::Identifier] the new identifier
  def mint_ark
    Ezid::Identifier.create
  end

  def find_or_create_contributors(fields, attrs)
    Hash.new.tap do |contributors|
      fields.each do |field|
        next unless attrs.key?(field)
        contributors[field] = []

        attributes[field].each do |value|
          if value.is_a?(RDF::URI)
            contributors[field] << value
          elsif value.is_a?(Hash)
            contributor = find_or_create_local_contributor(value.fetch(:type), value.fetch(:name))
            contributors[field] << contributor
          end
        end
      end
    end
  end

  def find_or_create_rights_holders(attrs)
    rights_holders = attrs.fetch(:rights_holder, []).map do |value|
      if value.is_a?(RDF::URI)
        value
      else
        find_or_create_local_rights_holder(value)
      end
    end

    rights_holders.blank? ? {} : { rights_holder: rights_holders }
  end

  private

    def find_or_create_local_contributor(type, name)
      klass = contributor_classes[type]
      contributor = klass.where(foaf_name_ssim: name).first || klass.create(foaf_name: name)
      RDF::URI.new(contributor.uri)
    end

    def find_or_create_local_rights_holder(name)
      rights_holder = Agent.exact_model.where(foaf_name_ssim: name).first
      rights_holder ||= Agent.create(foaf_name: name)
      RDF::URI.new(rights_holder.uri)
    end

    def host
      Rails.application.config.host_name
    end

    def path_for(obj)
      "http://#{host}/lib/#{obj.ark}"
    end

    # Map the MODS name type to the correct model.
    # Example:
    # <mods:name type="personal">
    # A name with type="personal" should map to the Person model
    def contributor_classes
      @contributor_classes ||= {
        'personal' => Person,
        'corporate' => Organization,
        'conference' => Group,
        'family' => Group }
    end

    def transform_attributes
      contributors = find_or_create_contributors(klass.contributor_fields, attributes)
      rights_holders = find_or_create_rights_holders(attributes)
      attributes.merge(contributors).merge(rights_holders)
    end
end
