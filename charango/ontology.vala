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

/*
 * Charango.Ontology: class for parsing and ontologies
 */
public class Charango.Ontology: Entity {

internal Charango.Context context;

public bool builtin = false;
public bool loaded = false;
public bool external = false;

public List<string> alias_list = null;

public Charango.Ontology? required_by = null;

/**
 * source_file_name: on-disk source of the ontology
 */
public string? source_file_name;

/**
 * prefix: Ontology prefix
 */
public string? prefix;

/* List of ontologies which have contributed to this definition */
/* FIXME: still needed? */
protected List<Charango.Ontology> external_def_list = null;

/* FIXME: really, classes and properties are entities as well. ... */
internal List<Charango.Entity>   entity_list = null;
internal List<Charango.Class>    class_list = null;
internal List<Charango.Property> property_list = null;

public Ontology (Context        context,
                 string         uri,
                 Charango.Class rdf_type,
                 string?        source_file_name,
                 string?        prefix)
       throws ParseError {
	unichar terminator = uri[uri.length-1];
	if (terminator != '#' && terminator != '/')
		throw new ParseError.INVALID_URI ("Namespace must end in # or /; got '%s'", uri);

	base (uri, rdf_type);

	this.context = context;
	this.source_file_name = source_file_name;
	this.prefix = prefix;

	if (source_file_name == null)
		this.external = true;

	this.entity_list.prepend (this);
}

private string get_format_for_file (string file_name) {
	// FIXME: redland seems to be broken on this front; internally,
	// raptor_guess_parser_name_v2() is passed a world of 0 from
	// raptor_guess_parser_name() and thus segfaults.

	/*string parser_name = Rdf.Parser.guess_name (redland, "/foo", "fuck", "you");
	print ("Got parser: %s\n", parser_name);*/

	// FIXME: A dumb guessing game. We default to turtle.
	//
	int dot_index = file_name.last_index_of_char ('.');	
	if (dot_index == -1)
		return "turtle";

	string extension = file_name[dot_index+1:file_name.length];

	if (extension == "rdf" || extension == "xml" || extension == "owl")
		return "rdfxml";

	// this is what works, not sure why .. 
	if (extension == "n3")
		return "turtle";

	return "turtle";
}

private Entity create_entity (string         uri,
                              Charango.Class type)
               throws ParseError, OntologyError {
	switch (type.get_concept_type ()) {
		case ConceptType.ONTOLOGY:
			// This function is called for resources that don't already exist, and
			// all ontologies are created on init according to the INDEX so we
			// should not get here.
			throw new OntologyError.INVALID_DEFINITION
			  ("Ontology object for %s should already exist. You may have set " +
			   "the URI incorrectly in INDEX; or the file may try to define " +
			   "more than one ontology (which is not permitted)", uri);
		case ConceptType.CLASS:
			return new Charango.Class (this, uri, type, context.max_class_id ++);
		case ConceptType.PROPERTY:
			return new Charango.Property (this, uri, type);
		case ConceptType.ENTITY:
		default:
			return new Charango.Entity (uri, type);
	}
}

/* load:
 * @dependency_list: required namespaces that are not yet available will be
 *                   added to this list.
 * @warning_list: warnings are added to this list.
 * 
 * Load ontology into memory.
 */
internal void load (ref List<Warning>  warning_list)
         throws ParseError, OntologyError

         /* external ontologies cannot be loaded */
         requires (this.external == false)
         requires (this.source_file_name != null)
{
	Rdf.World *redland = context.redland;

	tracel (1, "ontology", "Loading %s from %s\n", this.uri, this.source_file_name);

	/* Parse and retrieve as a linear stream */
	var parser_name = get_format_for_file (this.source_file_name);

	var parser = new Rdf.Parser (redland, parser_name, null, null);
	var storage = new Rdf.Storage (redland, null, null, null);
	var model = new Rdf.Model (redland, storage, null);

	var file_uri = new Rdf.Uri.from_filename (redland, this.source_file_name);
	var base_uri = new Rdf.Uri (redland, this.uri);
	parser.parse_into_model (file_uri, base_uri, model);

	Rdf.Stream stream = model.as_stream ();
	while (! stream.end()) {
		unowned Rdf.Statement statement = stream.get_object ();

		unowned Rdf.Node subject_node = statement.get_subject ();
		unowned Rdf.Node arc_node = statement.get_predicate ();
		unowned Rdf.Node object_node = statement.get_object ();

		stream.next ();

		if (subject_node.is_blank ())
			/* Not handled yet */
			//print ("Warning: blank node\n");
			continue;

		if (subject_node.is_literal() || !arc_node.is_resource() ||
		    (!object_node.is_literal() && !object_node.is_resource())) {
			warning_list.prepend (new Warning ("Invalid statement: <%s %s %s>",
			                                   subject_node.to_string (),
			                                   arc_node.to_string (),
			                                   object_node.to_string ()));
			continue;
		}

		/* FIXME: an obvious optimisation here is to check if subject is the
		 * same as the previous subject (node pointers will be equal) and if
		 * it is, entity will also be the same
		 */
		string  uri_string = subject_node.get_uri().as_string();
		Entity? subject;

		/* FIXME: need to handle external namespaces for subject - in this case it's
		 * an external definition, so really we can just add them as stubs and not
		 * put them on the dependency list. ... Shouldn't be allowed to do anything
		 * other than declare rdf:type of an external object.*/

		try {
			subject = this.find_local_entity (uri_string);
		}
		  catch (OntologyError error) {
			if (! (error is OntologyError.UNKNOWN_RESOURCE))
				throw (error);

			subject = null;
		  }

		if (arc_node.equals (context.redland->concept (Concept.MS_type))) {
			Class type = (Charango.Class) context.find_or_create_class
			                                (this,
			                                 object_node.get_uri().as_string());
			if (subject == null) {
				subject = create_entity (uri_string, type);

				if (subject is Charango.Class)
					this.class_list.prepend ((Charango.Class) subject);
				else if (subject is Charango.Property)
					this.property_list.prepend ((Charango.Property) subject);
				else
					this.entity_list.prepend (subject);
			} else {
				// Resource already exists, it was referenced in advance of being
				// defined. It could be a property or a class and we didn't know.

				if (subject.requires_promotion (type)) {
					// It's not possible to reallocate a GObject .... so instead we will
					// have to update every pointer in the context :(
					var old_entity = subject;
					subject = create_entity (old_entity.uri, type);
					subject.copy_properties (old_entity);
					context.replace_entity (old_entity, subject);
					/* FIXME: Also, we theoretically need to update all instances of
					 * subject, if subject's type is rdfs:Class and it has for example been
					 * made an rdfs:subClassOf rdf:Property. That can be a special
					 * case property accessor on CharangoClass.
					 */
				}

				subject.rdf_type = type;
			}
		} else {
			if (subject == null) {
				subject = create_entity (uri_string, context.rdf_resource);
				this.entity_list.prepend (subject);
			}

			/* FIXME: because replacing entities after the fact is an expensive operation,
			 * we should do our best to create the correct concept type here; the range
			 * of 'arc' should give a good idea
			 */
			string arc_uri = arc_node.get_uri().as_string();
			Entity arc = context.find_or_create_entity (this, arc_uri);

			if (object_node.is_literal ())
				subject.set_literal (arc_uri, object_node);
			else if (object_node.is_resource ()) {
				Entity object;
				string object_uri = object_node.get_uri().as_string ();
				try {
					object = context.find_or_create_entity
					           (this,
					            object_uri,
					            /*arc.range.get_concept_type ()*/ ConceptType.ENTITY);
					subject.set_entity (arc_uri, object);
				}
				catch (ParseError e) {
					if (e is ParseError.UNKNOWN_NAMESPACE)
						// Value is an external resource
						subject.set_external_resource (arc_uri, object_uri);
					else
						throw e;
				}
			}
		}
	}
}

internal Charango.Entity find_local_entity (string uri)
                         throws OntologyError {
	try {
		return find_local_class (uri);
	}
	  catch (OntologyError e) { }

	try {
		return find_local_property (uri);
	}
	  catch (OntologyError e) {
	  }

	foreach (Charango.Entity e in this.entity_list)
		if (e.uri == uri)
			return e;

	if (uri == this.uri || (uri + "#") == this.uri || (uri + "/") == this.uri)
		return this;

	throw new OntologyError.UNKNOWN_RESOURCE ("Unable to find entity '%s'", uri);
}

internal Charango.Class find_local_class (string uri)
                        throws OntologyError {
	foreach (Charango.Class c in this.class_list)
		if (c.uri == uri)
			return c;

	throw new OntologyError.UNKNOWN_CLASS ("Unable to find class '%s'", uri);
}

internal Charango.Property find_local_property (string uri)
                        throws OntologyError {
	foreach (Charango.Property p in this.property_list)
		if (p.uri == uri)
			return p;

	throw new OntologyError.UNKNOWN_PROPERTY ("Unable to find property '%s'", uri);
}

internal void replace_entity (Entity old_entity,
                              Entity new_entity) {
	if (old_entity is Charango.Class)
		this.class_list.remove ((Charango.Class) old_entity);
	else if (old_entity is Charango.Property)
		this.property_list.remove ((Charango.Property) old_entity);
	else
		this.entity_list.remove (old_entity);

	if (new_entity is Charango.Class)
		this.class_list.prepend ((Charango.Class) new_entity);
	else if (new_entity is Charango.Property)
		this.property_list.prepend ((Charango.Property) new_entity);
	else
		this.entity_list.prepend (new_entity);

	foreach (Entity e in this.entity_list) {
		/* FIXME: Replace all of the properties - including rdf_type? That
		 * shouldn't be possible though, we should guess the types
		 */
	}

	foreach (Entity e in this.class_list) {
		/* Replace all of the properties - including rdf_type? That
		 * shouldn't be possible though, we should guess the types
		 */
	}
	foreach (Entity e in this.property_list) {
		/* Replace all of the properties - including rdf_type? That
		 * shouldn't be possible though, we should guess the types
		 */
	}
}

public override void dump () {
	print ("charango ontology: %s [%s]\n", uri.to_string(), prefix);
	foreach (Charango.Class rdfs_class in class_list) {
		assert (rdfs_class != null);
		print ("\tclass %i: ", 1); rdfs_class.dump();
	}
	foreach (Charango.Property rdfs_property in property_list) {
		print ("\tproperty %i: ", 1); rdfs_property.dump();
	}
}

}
