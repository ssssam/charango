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

HashTable<string, Charango.Namespace> namespace_table;
List<Charango.Ontology> ontology_list = null;

/* Fundamental constants of the universe */
public Charango.Property rdf_type;
public Charango.Class rdfs_resource;
public Charango.Class rdf_property;
public Charango.Class rdfs_class;
public Charango.Class rdfs_literal;
public Charango.Class owl_ontology_class;

internal int max_class_id = 0;

public Context() {
	// We do some general initialisation here
	GLib.Log.set_handler ("Charango", 0xFFFF<<8, glib_logger);

	redland = new Rdf.World();

	redland->set_logger (redland_logger);

	// Create the fundamental concepts of the universe
	var xsd_namespace = new Charango.Namespace.builtin_internal
	                      (this, "http://www.w3.org/2001/XMLSchema#", "xsd");
	var rdf_namespace = new Charango.Namespace.builtin_internal
	                      (this, "http://www.w3.org/1999/02/22-rdf-syntax-ns#", "rdf");
	var rdfs_namespace = new Charango.Namespace.builtin_internal
	                      (this, "http://www.w3.org/2000/01/rdf-schema#", "rdfs");
	var owl_namespace = new Charango.Namespace.builtin_internal
	                      (this, "http://www.w3.org/2002/07/owl#", "owl");

	// No external definition of XML Schema, it makes no sense as RDF
	xsd_namespace.loaded = true;

	this.namespace_table = new HashTable<string, Charango.Namespace> (str_hash, str_equal);
	this.namespace_table.insert (xsd_namespace.uri, xsd_namespace);
	this.namespace_table.insert (rdf_namespace.uri, rdf_namespace);
	this.namespace_table.insert (rdfs_namespace.uri, rdfs_namespace);
	this.namespace_table.insert (owl_namespace.uri, owl_namespace);

	rdf_type = new Charango.Property.prototype
	  (rdf_namespace, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type");

	rdfs_resource = new Charango.Class.prototype
	  (rdfs_namespace, "http://www.w3.org/2000/01/rdf-schema#Resource", this.max_class_id ++);

	rdf_property = new Charango.Class.prototype
	  (rdf_namespace, "http://www.w3.org/1999/02/22-rdf-syntax-ns#Property", this.max_class_id ++);

	rdfs_class = new Charango.Class.prototype
	  (rdfs_namespace, "http://www.w3.org/2000/01/rdf-schema#Class", this.max_class_id ++);

	rdfs_literal = new Charango.LiteralClass (rdfs_namespace, "Literal", typeof (string), this.max_class_id ++);

	owl_ontology_class = new Charango.Class.prototype
	  (owl_namespace, "http://www.w3.org/2002/07/owl#Ontology", this.max_class_id ++);

	// Maxwell's equations
	rdfs_class.main_parent = rdfs_resource;
	rdfs_resource.rdf_type = rdfs_class;
	rdf_property.rdf_type = rdfs_class;
	rdfs_class.rdf_type = rdfs_class;
	rdf_type.rdf_type = rdf_property;
	owl_ontology_class.rdf_type = rdfs_class;

	this.ontology_list.prepend (new XsdOntology (xsd_namespace));
	this.ontology_list.prepend (new RdfOntology (rdf_namespace));
	this.ontology_list.prepend (new RdfsOntology (rdfs_namespace));
	this.ontology_list.prepend (new OwlOntology (owl_namespace));
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
            throws FileError, RdfError {
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
		throw new RdfError.INDEX_PARSE_ERROR (error.message);
	  }

	foreach (string namespace_uri in index.get_groups()) {
		string  filename = null;
		string? prefix = null;
		bool    ignore = false;

		try {
			if (index.has_key (namespace_uri, "file")) {
				filename = index.get_string (namespace_uri, "file");
				filename = Path.build_filename (path, filename);
			}

			if (index.has_key (namespace_uri, "prefix"))
				prefix = index.get_string (namespace_uri, "prefix");

			if (index.has_key (namespace_uri, "ignore"))
				ignore = index.get_boolean (namespace_uri, "ignore");
		}
		  catch (KeyFileError error) {
			throw new RdfError.INDEX_PARSE_ERROR (error.message);
		  }

		var ns = this.find_namespace (namespace_uri);

		if (ns == null) {
			ns = new Charango.Namespace (this, namespace_uri, prefix);
			this.namespace_table.insert (namespace_uri, ns);
		}

		if (ignore == true) {
			//print ("Ignoring: %s\n", ns.uri);
			ns.ignore = true;
			continue;
		}

		if (filename == null)
			throw new RdfError.INDEX_PARSE_ERROR
			  ("%s: Namespace must have an associated ontology file",
			   namespace_uri);

		if (ns.ontology == null) {
			var ontology = new Ontology (ns, namespace_uri, this.owl_ontology_class, filename);
			ns.set_ontology (ontology);
			this.ontology_list.prepend (ontology);
		} else {
			// Ontology may have had some internal definitions. We still
			// make sure only one external file to defines it.
			if (ns.ontology.source_file_name != null)
				throw new RdfError.DUPLICATE_DEFINITION
				  ("%s: Ontology for namespace %s is already defined in file %s",
				   filename,
				   namespace_uri,
				   ns.ontology.source_file_name);

			warn_if_fail (ns.builtin);
		}

		ns.ontology.source_file_name = filename;

		try {
			if (index.has_key (namespace_uri, "alias"))
				foreach (string alias_uri in index.get_string_list (namespace_uri, "alias"))
					this.namespace_table.insert (alias_uri, ns);
		}
		  catch (KeyFileError error) {
			throw new RdfError.INDEX_PARSE_ERROR (error.message);
		  }

		//print ("Registered: %s in %s\n", ns.uri, ns.ontology.source_file_name);
	}
}

/**
 * load_namespace():
 * @uri: URI string that identifies the ontology namespace
 *
 * Loads an ontology and all of its dependencies into memory. The
 * ontology must be available in a directory that has been added using
 * add_local_ontology_source().
 */
public void load_namespace (string            uri,
                            out List<Warning> warning_list = null)
            throws FileError, RdfError {
	List<Charango.Namespace> load_list = null;

	var root = this.find_namespace (uri);

	if (root == null)
		throw new RdfError.UNKNOWN_NAMESPACE
		  ("load_namespace(): '%s' is not available in any ontology source.", uri);

	load_list.append (root);

	while (load_list != null) {
		// All namespaces referenced in 'ontology' that are available but
		// not yet loaded will be queued for reading
		var current_namespace = load_list.data;
		load_list.remove_link (load_list);

		if (current_namespace.loaded)
			continue;

		if (current_namespace.ontology == null)
			throw new RdfError.MISSING_DEFINITION
			  ("No ontology available for namespace: %s", current_namespace.uri);

		current_namespace.ontology.load (ref warning_list);
		current_namespace.loaded = true;

		Charango.Namespace ns;
		var iter = HashTableIter<string, Charango.Namespace> (this.namespace_table);

		while (iter.next (null, out ns))
			if (ns.required_by == current_namespace && ! ns.loaded && ! ns.external)
				load_list.prepend (ns);
	}
}

public List<unowned Charango.Namespace> get_namespace_list () {
	Charango.Namespace ns;
	var iter = HashTableIter<string, Charango.Namespace> (this.namespace_table);
	List<unowned Charango.Namespace> result = null;

	while (iter.next (null, out ns))
		if (ns.ignore == false && result.find (ns) == null)
			result.prepend (ns);

	return result;
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
                       throws RdfError {
	string namespace_uri, entity_name;

	parse_uri_as_resource_strings (uri, out namespace_uri, out entity_name);

	Namespace ns = find_namespace (namespace_uri);

	if (ns == null)
		throw new RdfError.UNKNOWN_NAMESPACE
		  ("find_entity: Unknown namespace for resource <%s>", uri);

	return ns.find_local_entity (uri);
}

public Charango.Class? find_class (string uri) {
	try {
		return find_class_with_error (uri);
	}
	  catch (Charango.RdfError e) {
		warning ("%s", e.message);
		return null;
	  }
}

public Charango.Class find_class_with_error (string uri)
                      throws RdfError {
	string namespace_uri, class_name;

	parse_uri_as_resource_strings (uri, out namespace_uri, out class_name);

	Charango.Namespace ns = find_namespace (namespace_uri);

	if (ns == null)
		throw new RdfError.UNKNOWN_NAMESPACE
		  ("find_entity: Unknown namespace for resource <%s>", uri);

	return ns.find_local_class (uri);
}

public Charango.Property? find_property (string uri) {
	try {
		return find_property_with_error (uri);
	}
	  catch (Charango.RdfError e) {
		warning ("%s", e.message);
		return null;
	  }
}

public Charango.Property find_property_with_error (string uri)
                         throws RdfError {
	string namespace_uri, property_name;

	parse_uri_as_resource_strings (uri, out namespace_uri, out property_name);

	Charango.Namespace ns = find_namespace (namespace_uri);

	if (ns == null)
		throw new RdfError.UNKNOWN_NAMESPACE
		  ("find_entity: Unknown namespace for resource <%s>", uri);

	return ns.find_local_property (uri);
}

public Charango.Namespace? find_namespace (string uri) {
	Charango.Namespace? result = this.namespace_table.lookup (uri);

	if (result == null)
		result = this.namespace_table.lookup (uri + "#");

	if (result == null)
		result = this.namespace_table.lookup (uri + "/");

	return result;
}

/* process_uri:
 *
 * General preprocessing for user-supplied URI's.
 */
private Charango.Namespace? process_uri (string      uri,
                                         out string  canonical_uri,
                                         out string? entity_name)
                            throws Charango.RdfError {
	Charango.Namespace? ns;
	string ns_uri;

	parse_uri_as_resource_strings (uri, out ns_uri, out entity_name);

	ns = find_namespace (ns_uri);

	// Corner cases where URI is for the actual namespace, so entity_name is
	// blank and we don't get the correct namespace_uri.
	// FIXME: this is a weird way of working; parse_uri purports to be able
	// to split the URI but actually it cannot because it can't tell what's
	// a valid namespace URI.
	if (ns == null) {
		ns = find_namespace (uri);

		if (ns == null)
			throw new RdfError.UNKNOWN_NAMESPACE ("Unknown namespace for '%s'", uri);

		entity_name = null;
	}

	// 'uri' may have used an alias of the real namespace
	canonical_uri = ns.uri + entity_name;

	return ns;
}

private Entity create_entity (Charango.Namespace ns,
                              string             uri,
                              Charango.Class     type)
               throws Charango.RdfError {
	switch (type.get_concept_type ()) {
		case ConceptType.ONTOLOGY:
			// This function is called for resources that don't already exist, and
			// all ontologies are created on init according to the INDEX so we
			// should not get here.
			throw new RdfError.INVALID_DEFINITION
			   ("Ontology object for %s should already exist. You may have set " +
			    "the URI incorrectly in INDEX; or the file may try to define " +
			    "more than one ontology (which is not permitted)", uri);
		case ConceptType.CLASS:
			return new Charango.Class (ns, uri, type, this.max_class_id ++);
		case ConceptType.PROPERTY:
			return new Charango.Property (ns, uri, type);
		case ConceptType.ENTITY:
		default:
			return new Charango.Entity (ns, uri, type);
	}
}

/* find_or_create_entity:
 * @owner: a Charango.Ontology
 * @uri: identifier string
 * @expected_type: a Charango.Class, or %NULL
 * @allow_unknown_namespace: behaviour if the namespace of @uri is
 *                           unknown.
 * 
 * Used during ontology loading to handle forward references. Should really
 * be named find_or_create_and_promote_if_necessary(). This function will
 * refuse to add to an ontology that is marked as already having loaded.
 * 
 * @owner is the ontology which is currently being processed - it is used to
 * record the *reason* for the resource's creation.
 *
 * If the namespace of @uri is unknown and @allow_unknown_namespace is
 * %TRUE, the namespace will be created for the new entity. If it is
 * %FALSE, the function will throw #RdfError.UNKNOWN_NAMESPACE.
 */
internal Entity find_or_create_entity (Ontology        owner,
                                       string          uri,
                                       Charango.Class? expected_type,
                                       bool            allow_unknown_namespace)
                throws RdfError {
	Charango.Namespace ns;
	string  canonical_uri;
	string? entity_name;

	if (expected_type == null)
		expected_type = this.rdfs_resource;

	try {
		ns = process_uri (uri, out canonical_uri, out entity_name);
	}
	catch (RdfError e) {
		if (e is RdfError.UNKNOWN_NAMESPACE && allow_unknown_namespace) {
			string ns_uri;
			parse_uri_as_resource_strings (uri, out ns_uri, null);

			ns = new Charango.Namespace (this, ns_uri, null);
			ns.external = true;
			this.namespace_table.insert (ns_uri, ns);

			canonical_uri = ns_uri + entity_name;
		}
		else
			throw (e);
	}

	if (ns.ignore)
		// This error should always be handled by the caller, it's an
		// exception only for convenience.
		throw new RdfError.IGNORED_NAMESPACE (ns.uri);

	if (! ns.loaded /*&& ! ns.external*/)
		if (ns.required_by == null)
			ns.required_by = owner.ns;

	Entity? e = null;
	try {
		e = ns.find_local_entity (canonical_uri);
	}
	catch (RdfError.UNKNOWN_RESOURCE error) {
		if (ns.loaded)
			throw error;
	}

	if (e == null) {
		e = create_entity (ns, canonical_uri, expected_type);

		switch (expected_type.get_concept_type ()) {
			case ConceptType.ENTITY:
				ns.entity_list.prepend (e);
				break;
			case ConceptType.CLASS:
				ns.class_list.prepend ((Charango.Class) e);
				break;
			case ConceptType.PROPERTY:
				ns.property_list.prepend ((Charango.Property) e);
				break;
			case ConceptType.ONTOLOGY:
			default:
				warn_if_reached ();
				break;
		}
	} else
	if (e.requires_promotion (expected_type)) {
		// It's not possible to reallocate a GObject .... so instead we will
		// have to update every pointer in the context :(
		//
		// Note that expected_type may be rdf:Resource when in fact e is an
		// owl:Ontology or something else quite grand; we only ever need to
		// promote UP so this crude system actually works perfectly.
		var old_entity = e;
		e = create_entity (ns, old_entity.uri, expected_type);
		e.copy_properties (old_entity);
		this.replace_entity (old_entity, e);
		/* FIXME: Also, we theoretically need to update all instances of
		 * subject, if subject's type is rdfs:Class and it has for example been
		 * made an rdfs:subClassOf rdf:Property. That can be a special
		 * case property accessor on CharangoClass.
		 */
	}

	return e;
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
	var iter = HashTableIter<string, Charango.Namespace> (this.namespace_table);
	Charango.Namespace ns;
	while (iter.next (null, out ns))
		ns.replace_entity (old_entity, new_entity);
}

public void dump () {
}

}
