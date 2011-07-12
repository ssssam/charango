/*  Charango
 *  Copyright 2011 Sam Thursfield <ssssam@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Rdf;

/**
 * Charango.Context: global state object
 *
 * Object representing the state of all Charango data. Holds all the ontology
 * graphs etc.
 */
public class Charango.Context: GLib.Object {

/* FIXME: currently we cannot allow the world to be freed. The issue is that rdf_free_world()
 * causes the destruction of all librdf objects. However, Vala frees the Charango.Context data
 * in some order which has the World freed first, and then things which still have librdf
 * objects. Thus, everything is double freed :(
 */
internal Rdf.World *redland;

List<Ontology> ontology_list = null;

/* Fundamental constants of the universe */
public Charango.Class rdf_resource;
public Charango.Class rdfs_class;
public Charango.Class owl_ontology_class;

internal int max_class_id = 0;

public Context() {
	// We do some general initialisation here
	GLib.Log.set_handler ("Charango", 0xFFFF<<8, glib_logger);

	redland = new Rdf.World();

	redland->set_logger (redland_logger);

	// Create the fundamental concepts
	rdf_resource = new Charango.RdfResource ();
	rdf_resource.id = this.max_class_id ++;

	rdfs_class = new Charango.RdfsClass ();
	rdfs_class.id = this.max_class_id ++;

	rdf_resource.rdf_type = rdfs_class;
	rdfs_class.main_parent = rdf_resource;

	owl_ontology_class = new Charango.OwlOntologyClass2 (rdfs_class);
	owl_ontology_class.id = this.max_class_id ++;

	ontology_list.prepend (new XsdOntology (this));
	ontology_list.prepend (new RdfOntology (this));
	ontology_list.prepend (new RdfsOntology (this));
	ontology_list.prepend (new OwlOntology (this));
}

/**
 * add_local_ontology_source():
 * @path: location to search for files
 *
 * Registers all ontology files at @path. These will be loaded when
 * context.require() is called. @path must contain an INDEX file, which is
 * a #GKeyFile that maps the files to namespaces in the following format:
 *
 *    [http://www.w3.org/1999/02/22-rdf-syntax-ns#]
 *    File=22-rdf-syntax-ns.xml
 *    Prefix=rdf
 *
 */
public void add_local_ontology_source (string path)
            throws FileError, ParseError {
	if (! FileUtils.test (path, FileTest.EXISTS))
		throw new FileError.NOENT ("%s not found", path);
	if (! FileUtils.test (path, FileTest.IS_DIR))
		throw new FileError.NOTDIR ("%s is not a directory", path);

	var index = new KeyFile ();
	try {
		index.load_from_file (Path.build_filename (path, "INDEX"), KeyFileFlags.NONE);
	}
	  catch (FileError error) {
		error.message = "Unable to INDEX in %s: %s".printf (path, error.message);
		throw (error);
	  }
	  catch (KeyFileError error)  {
		throw new ParseError.INDEX_PARSE_ERROR (error.message);
	  }

	foreach (string rdf_namespace in index.get_groups()) {
		bool    external = false;
		string  filename = null;
		string? prefix = null;

		try {
			if (index.has_key (rdf_namespace, "file")) {
				filename = index.get_string (rdf_namespace, "file");
				filename = Path.build_filename (path, filename);

				if (index.has_key (rdf_namespace, "prefix"))
					prefix = index.get_string (rdf_namespace, "prefix");
			} else
			if (index.has_key (rdf_namespace, "external"))
				external = index.get_boolean (rdf_namespace, "external");
		}
		  catch (KeyFileError error) {
			throw new ParseError.INDEX_PARSE_ERROR (error.message);
		  }

		if (filename == null && external != true)
			throw new ParseError.INDEX_PARSE_ERROR
			  ("%s: Namespace must either have a file or be marked as external",
			   rdf_namespace);

		var ontology = this.find_ontology (rdf_namespace);
		if (ontology == null)
			ontology = new Ontology (this, rdf_namespace, this.owl_ontology_class, filename, prefix);
		else {
			if (ontology.source_file_name != null)
				throw new ParseError.DUPLICATE_DEFINITION
				  ("%s: Namespace %s is already defined in file %s",
				   filename,
				   rdf_namespace,
				   ontology.source_file_name);

			warn_if_fail (ontology.builtin);

			ontology.source_file_name = filename;
			ontology.prefix = prefix;
		}

		try {
			if (index.has_key (rdf_namespace, "alias"))
				foreach (string alias_uri in index.get_string_list (rdf_namespace, "alias"))
					if (ontology.alias_list.find (alias_uri) == null)
						ontology.alias_list.prepend (alias_uri);
		}
		  catch (KeyFileError error) {
			throw new ParseError.INDEX_PARSE_ERROR (error.message);
		  }

		this.ontology_list.prepend (ontology);
	}
}

/**
 * load_namespace():
 * @namespace_uri: URI string that identifies the namespace
 *
 * Loads an ontology and all of its dependencies into memory. The ontology must
 * be described in a file that has been added using add_local_ontology_source().
 */
public void load_namespace (string            uri,
                            out List<Warning> warning_list = null)
            throws FileError, ParseError, OntologyError {
	List<Ontology> load_list = null;

	load_list.append (this.find_ontology (uri));

	while (load_list != null) {
		// All namespaces referenced in 'ontology' that are available but
		// not yet loaded will be queued for reading
		var current_ontology = load_list.data;

		warn_if_fail (current_ontology.loaded == false);
		warn_if_fail (current_ontology.external == false);

		current_ontology.load (ref warning_list);

		current_ontology.loaded = true;
		load_list.remove_link (load_list);

		foreach (Ontology o in this.ontology_list)
			if (o.required_by == current_ontology && !o.loaded && !o.external)
				load_list.prepend (o);
	}
}

public List<Charango.Ontology> get_ontology_list () {
	return (owned) this.ontology_list;
}

/**
 * find_entity()
 * @uri: resource identifier string
 *
 * Locates the given entity, checking all known data sources.
 */
public Charango.Entity? find_entity (string uri) {
	try {
		return find_entity_with_error (uri);
	}
	  catch (Error error) {
		warning ("%s", error.message);
		return null;
	  }
}

public Charango.Entity find_entity_with_error (string uri)
                       throws ParseError, OntologyError {
	/* FIXME: let's hash the namespaces */

	string namespace_uri, entity_name;

	parse_uri_as_resource_strings (uri, out namespace_uri, out entity_name);

	Ontology o = find_ontology (namespace_uri);

	if (o == null)
		throw new ParseError.UNKNOWN_NAMESPACE
		  ("find_entity: Unknown namespace for resource <%s>", uri);

	return o.find_local_entity (uri);
}

public Charango.Class? find_class (string uri) {
	try {
		return find_class_with_error (uri);
	}
	  catch (Error e) {
		warning ("%s", e.message);
		return null;
	  }
}

public Charango.Class find_class_with_error (string uri)
                      throws OntologyError, ParseError {
	string namespace_uri, class_name;

	parse_uri_as_resource_strings (uri, out namespace_uri, out class_name);

	Ontology o = find_ontology (namespace_uri);

	if (o == null)
		throw new ParseError.UNKNOWN_NAMESPACE
		  ("find_entity: Unknown namespace for resource <%s>", uri);

	return o.find_local_class (uri);
}

private bool namespace_uris_match (string ns, string m) {
	if (ns == m)
		return true;
	if (ns.has_suffix("#") && ns == m + "#")
		return true;
	if (ns.has_suffix("/") && ns == m + "/")
		return true;
	return false;
}

public Ontology? find_ontology (string uri) {
	// FIXME: there must be a better way to search lists in vala
	foreach (Ontology o in ontology_list) {
		if (namespace_uris_match (o.uri, uri))
			return o;

		foreach (string alias_uri in o.alias_list)
			if (namespace_uris_match (alias_uri, uri))
				return o;
	}

	return null;
}

/* find_or_create_entity:
 * @expected_type: A hint for if Entity must be created. Not enforced.
 * 
 * Used during ontology loading to handle forward references.
 */
internal Entity find_or_create_entity (Ontology    owner,
                                       string      uri,
                                       ConceptType expected_type = ConceptType.ENTITY)
                throws OntologyError, ParseError {
	string namespace_uri, entity_name;

	parse_uri_as_resource_strings (uri, out namespace_uri, out entity_name);

	Ontology o = find_ontology (namespace_uri);

	// Corner cases where URI is for the actual namespace, so entity_name is
	// blank
	if (o == null) {
		o = find_ontology (uri);

		if (o != null) {
			namespace_uri = uri;
			entity_name = null;
		}
	}

	if (o == null)
		throw new ParseError.UNKNOWN_NAMESPACE
		  ("Unknown namespace for '%s' (required by %s)", uri, owner.uri);

	if (! o.loaded && ! o.external)
		if (o.required_by == null)
			o.required_by = owner;

	Entity e;
	try {
		e = o.find_local_entity (uri);
	}
	catch (OntologyError.UNKNOWN_RESOURCE error) {
		if (o.loaded)
			throw error;
		else {
			// Forward reference - just create the entity as a stub
			switch (expected_type) {
				case ConceptType.ENTITY:
					e = new Charango.Entity (uri, this.find_class ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Resource"));
					o.entity_list.prepend (e);
					break;
				case ConceptType.CLASS:
					e = new Charango.Class (owner, uri, this.find_class ("http://www.w3.org/2000/01/rdf-schema#Class"), this.max_class_id ++);
					o.class_list.prepend ((Charango.Class) e);
					break;
				case ConceptType.PROPERTY:
					e = new Charango.Property (owner, uri, this.find_class ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Property"));
					o.property_list.prepend ((Charango.Property) e);
					break;
				case ConceptType.ONTOLOGY:
				default:
					e = null;
					warn_if_reached ();
					break;
			}

		}
	}

	return e;
}

/* find_or_create_class:
 */
internal Charango.Class find_or_create_class (Ontology    owner,
                                              string      uri)
                throws OntologyError, ParseError {
	Charango.Entity e = find_or_create_entity (owner, uri, ConceptType.CLASS);

	if (e is Charango.Class)
		return (Charango.Class) e;

	if (e.rdf_type == rdf_resource) {
		// If the entity has no type info, it's probably been referenced already
		// a statement like rdf:range but we couldn't be sure it was a class.
		var c = new Charango.Class (owner, uri, rdfs_class, max_class_id ++);
		c.copy_properties (e);
		this.replace_entity (e, c);
		return c;
	}

	throw new OntologyError.TYPE_MISMATCH
	  ("%s used as rdfs:Class, but is of type %s", uri, e.rdf_type.to_string());
}

/* replace_entity:
 *
 * Update all pointers to 'old_entity' to point to 'new_entity'. The
 * speed of this is less than ideal of course, but we sometimes need to
 * if we don't discover the type of an class or a property straight away
 * because we can't promote the type of an existing GObject.
 */
public void replace_entity (Entity *old_entity,
                            Entity *new_entity) {
	foreach (Ontology o in ontology_list) {
		o.replace_entity (old_entity, new_entity);
	}
}

public void dump () {
}

}
