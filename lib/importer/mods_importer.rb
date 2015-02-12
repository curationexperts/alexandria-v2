module Importer
  class ModsImporter

    def initialize(files_directory, metadata_directory=nil)
      @files_directory = files_directory
      @metadata_directory = metadata_directory
    end

    def import_all
      count = 0
      Dir.glob("#{@metadata_directory}/**/*").each do |filename|
        next if File.directory?(filename)
        import(filename)
        count += 1
      end
      count
    end

    def import(file)
      puts "Importing: #{file}"
      parser = ModsParser.new(file)
      create_fedora_objects(parser.model, parser.attributes)
    rescue Oargun::RDF::Controlled::ControlledVocabularyError => e
      puts "  Skipping, due to #{e.message}"
    end

    # Select a factory to create the objects in fedora.
    # For example, if we are importing a MODS record for an
    # image, the ModsParser will return an Image model, so
    # we'll select the ImageFactory to create the fedora
    # objects.
    def create_fedora_objects(model, attributes)
      object_factory = (model.to_s + "Factory").constantize
      object_factory.new(attributes, @files_directory).run
    end

  end
end
