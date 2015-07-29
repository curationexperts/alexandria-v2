require 'concerns/relators'
module Metadata
  extend ActiveSupport::Concern

  RELATIONS = {
    contributor:         RDF::DC.contributor,
    creator:             RDF::DC.creator,
  }.merge(MARCREL)

  included do
    # For ARKs
    property :identifier, predicate: RDF::DC.identifier do |index|
      index.as :displayable
    end

    property :accession_number, predicate: RDF::URI('http://opaquenamespace.org/ns/cco/accessionNumber') do |index|
      index.as :symbol, :stored_searchable # symbol is needed for exact match search in the CollectionFactory
    end

    property :title, predicate: RDF::DC.title, multiple: false do |index|
      index.as :stored_searchable
    end

    property :alternative, predicate: RDF::DC.alternative do |index|
      index.as :stored_searchable
    end

    RELATIONS.each do |field_name, predicate|
      property field_name, predicate: predicate, class_name: Oargun::ControlledVocabularies::Creator do |index|
        index.as :stored_searchable, :facetable
      end
    end

    # property :creator, predicate: ::RDF::DC.creator, class_name: Oargun::ControlledVocabularies::Creator do |index|
    #   index.as :stored_searchable, :facetable
    # end
    # property :contributor, predicate: ::RDF::DC.contributor do |index|
    #   index.as :stored_searchable
    # end

    property :description, predicate: RDF::DC.description do |index|
      index.as :stored_searchable
    end

    property :latitude, predicate: RDF::EXIF.gpsLatitude do |index|
       index.as :displayable
    end

    property :language, predicate: RDF::DC.language,
      class_name: Oargun::ControlledVocabularies::Language do |index|
        index.as :displayable
    end

    property :longitude, predicate: RDF::EXIF.gpsLongitude do |index|
       index.as :displayable
    end

    property :location, predicate: RDF::DC.spatial,
      class_name: Oargun::ControlledVocabularies::Geographic do |index|
        index.as :stored_searchable, :facetable
    end

    property :place_of_publication, predicate: RDF::Vocab::MARCRelators.pup do |index|
      index.as :stored_searchable
    end

    property :lc_subject, predicate: RDF::DC.subject, class_name: Oargun::ControlledVocabularies::Subject do |index|
      index.as :stored_searchable, :facetable
    end

    property :institution, predicate: Oargun::Vocabularies::OARGUN.contributingInstitution, class_name: Oargun::ControlledVocabularies::Organization do |index|
      index.as :stored_searchable
    end

    property :publisher, predicate: RDF::DC.publisher do |index|
      index.as :stored_searchable, :facetable
    end

    property :rights_holder, predicate: RDF::DC.rightsHolder, class_name: Oargun::ControlledVocabularies::Creator do |index|
      index.as :symbol
    end

    property :copyright_status, predicate: RDF::Vocab::PREMIS.hasCopyrightStatus, class_name: Oargun::ControlledVocabularies::CopyrightStatus do |index|
      index.as :stored_searchable
    end

    property :license, predicate: RDF::DC.rights, class_name: Oargun::ControlledVocabularies::RightsStatement do |index|
      index.as :stored_searchable
    end

    property :work_type, predicate: RDF::DC.type do |index|
      index.as :stored_searchable
    end

    property :series_name, predicate: RDF::URI('http://opaquenamespace.org/ns/seriesName') do |index|
      index.as :displayable
    end

    # Dates
    has_and_belongs_to_many :created, predicate: RDF::DC.created, class_name: 'TimeSpan', inverse_of: :images
    has_and_belongs_to_many :date_other, predicate: RDF::DC.date, class_name: 'TimeSpan', inverse_of: :date_other_images
    has_and_belongs_to_many :date_copyrighted, predicate: RDF::DC.dateCopyrighted, class_name: 'TimeSpan', inverse_of: :date_copyrighted_images
    has_and_belongs_to_many :date_valid, predicate: RDF::DC.valid, class_name: 'TimeSpan', inverse_of: :date_valid_images

    # Not tackling these now. No demonstrated need yet.
    # has_and_belongs_to_many :date_accepted, predicate: RDF::DC.dateAccepted, class_name: 'TimeSpan'
    # has_and_belongs_to_many :date_submitted, predicate: RDF::DC.dateSubmitted, class_name: 'TimeSpan'


    # RDA
    property :form_of_work, predicate: RDF::URI('http://www.rdaregistry.info/Elements/w/#formOfWork.en'),
        class_name: Oargun::ControlledVocabularies::WorkType do |index|
      index.as :stored_searchable, :facetable
    end

    property :citation, predicate: RDF::URI('http://www.rdaregistry.info/Elements/u/#preferredCitation.en')

    # MODS
    property :digital_origin, predicate: RDF::Vocab::MODS.digitalOrigin do |index|
      index.as :stored_searchable
    end

    property :description_standard, predicate: RDF::Vocab::MODS.recordDescriptionStandard

    property :extent, predicate: RDF::DC.extent do |index|
      index.as :searchable, :displayable
    end

    property :sub_location, predicate: RDF::Vocab::MODS.locationCopySublocation do |index|
      index.as :displayable
    end

    property :record_origin, predicate: RDF::Vocab::MODS.recordOrigin

    property :use_restrictions, predicate: RDF::Vocab::MODS.accessCondition do |index|
      index.as :stored_searchable
    end

    has_and_belongs_to_many :notes, predicate: RDF::Vocab::MODS.note

    def self.contributor_fields
      RELATIONS.keys
    end

    belongs_to :admin_policy, class_name: "Hydra::AdminPolicy", predicate: ActiveFedora::RDF::ProjectHydra.isGovernedBy
  end

  def time_span_blank(attributes)
    time_span_attributes.all? do |key|
      Array(attributes[key]).all?(&:blank?)
    end
  end

  def time_span_attributes
    [:start, :start_qualifier, :finish, :finish_qualifier, :label, :note]
  end

  def controlled_properties
    @controlled_properties ||= self.class.properties.each_with_object([]) do |(key, value), arr|
      if value["class_name"] && (value["class_name"] < ActiveTriples::Resource || value["class_name"].new.resource.class < ActiveTriples::Resource)
        arr << key
      end
    end
  end

  def ark
    identifier.first
  end
end
