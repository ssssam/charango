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

public List<string> alias_list = null;

/**
 * source_file_name: on-disk source of the ontology
 */
public string? source_file_name;

public Ontology (Charango.Namespace ns,
                 string             uri,
                 Charango.Class     rdf_type,
                 string?            source_file_name) /* FIXME: still need source_file_name ?? */
       throws RdfError {
	unichar terminator = uri[uri.length-1];
	if (terminator != '#' && terminator != '/')
		throw new RdfError.URI_PARSE_ERROR ("Namespace must end in # or /; got '%s'", uri);

	base (ns, uri, rdf_type);

	this.source_file_name = source_file_name;
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

/* load:
 * @warning_list: warnings are appended to this list.
 * 
 * Load ontology into memory.
 */
internal void load (ref List<Warning>  warning_list)
         throws RdfError {
	Charango.Context context = this.ns.context;
	Rdf.World *redland = context.redland;

	if (this.source_file_name == null)
		throw new RdfError.MISSING_DEFINITION
		  ("Missing ontology definition for %s", ns.uri);

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

		if (subject_node.is_literal() || !arc_node.is_resource()) {
			warning_list.prepend (new Warning (
				"Invalid statement: <%s %s %s>",
				subject_node.to_string (), arc_node.to_string (), object_node.to_string ()
			));
			continue;
		}

		if (subject_node.is_blank ()) {
			warning_list.prepend (new Warning (
				"Ignored statement due to blank: <%s %s %s>",
				subject_node.to_string (), arc_node.to_string (), object_node.to_string ()
			));
			continue;
		}

		string subject_uri = subject_node.get_uri().as_string();
		string arc_uri = arc_node.get_uri().as_string();

		Class subject_type = null;

		if (arc_uri == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type") {
			if (! object_node.is_resource()) {
				warning_list.prepend (new Warning ("Invalid statement: <%s %s %s>",
				                                   subject_node.to_string (),
				                                   arc_node.to_string (),
				                                   object_node.to_string ()));
				continue;
			}

			string object_uri = object_node.get_uri().as_string();
			subject_type = (Charango.Class) context.find_or_create_entity
			                 (this, object_uri, context.rdfs_class, true);
		}

		/* FIXME: support containers! http://www.infowebml.ws/website/_n.htm */
		if (arc_uri.length > 44 &&
		    arc_uri.substring (0, 44) == "http://www.w3.org/1999/02/22-rdf-syntax-ns#_" &&
		    (int)arc_uri.substring (44) > 0) {
			warning_list.prepend (new Warning (
				"Ignored statement due to container: <%s %s %s>",
				subject_node.to_string (), arc_node.to_string (), object_node.to_string ()
			));
			continue;
		}

		/* FIXME: an obvious optimisation here is to check if subject is the
		 * same as the previous subject (node pointers will be equal) and if
		 * it is, entity will also be the same
		 */

		Entity?  subject = null;
		Property arc;

		try {
			subject = context.find_or_create_entity
			            (this, subject_uri, subject_type, true);
			arc = (Charango.Property) context.find_or_create_entity
			            (this, arc_uri, context.rdf_property, false);
		}
		catch (Charango.RdfError e) {
			if (e is RdfError.IGNORED_NAMESPACE)
				// Ignore any triple with an ignored subject or arc, let's
				// assume whoever wrote the INDEX knew what they were doing
				continue;
			else
				throw (e);
		}

		if (subject_type != null)
			// We're done if this was an rdf:type statement
			continue;

		if (object_node.is_literal ())
			subject.set_literal (arc.uri, object_node);
		else if (object_node.is_resource ()) {
			/* FIXME: because replacing entities after the fact is an expensive operation,
			 * we should do our best to create the correct concept type here; the range
			 * of 'arc' should give a good idea
			 */

			Entity object;
			string object_uri = object_node.get_uri().as_string ();
			object = context.find_or_create_entity (this,
			                                        object_uri,
			                                        /*arc.range.get_concept_type ()*/ null,
			                                        true);
			subject.set_entity (arc.uri, object);
		}
		else if (object_node.is_blank ())
			warning_list.prepend (new Warning (
				"Ignored statement due to blank: <%s %s %s>",
				subject_node.to_string (), arc_node.to_string (), object_node.to_string ()
			));
	}
}

}
