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
 * Charango.Namespace
 */
public class Charango.Namespace: GLib.Object {

internal Charango.Context context;

public bool builtin = false;
public bool loaded = false;

/**
 * ignore:
 * Set in INDEX. causes any statements with subject or predicate in this
 * namespace to be discarded.
 */
public bool ignore = false;

/**
 * external:
 * Set on namespaces created due to appearing the subject or object of a
 * statement but being otherwise unknown.
 */
public bool external = false;

public Charango.Namespace? required_by = null;

public Charango.Ontology? ontology = null;

public List<string> alias_list = null;

public string  uri;
public string? prefix;

/* FIXME: really, classes and properties are entities as well. ... */
/* Should we store these in the Charango.Ontology? I think not, because some
 * namespaces do not have an ontology defined, definitions come from other
 * places ...
 */
internal List<Charango.Entity>   entity_list = null;
internal List<Charango.Class>    class_list = null;
internal List<Charango.Property> property_list = null;

public Namespace (Context context,
                  string  uri,
                  string? prefix)
       throws ParseError {
	unichar terminator = uri[uri.length-1];
	if (terminator != '#' && terminator != '/')
		throw new ParseError.INVALID_URI ("Namespace must end in # or /; got '%s'", uri);

	this.context = context;

	this.uri = uri;
	this.prefix = prefix;
}

public Namespace.builtin_internal (Context context,
                                   string  uri,
                                   string? prefix) {
	try {
		this (context, uri, prefix);
	}
	catch (ParseError e) { warning (e.message); }

	this.builtin = true;
}

internal void set_ontology (Ontology o) {
	this.ontology = o;

	// Don't treat the ontology as an entity, it's inconsistent because we
	// don't treat classes or properties are entities either.
	/*this.entity_list.prepend (o);*/
}

public List<Charango.Class> get_class_list () {
	return (owned) this.class_list;
}

public List<Charango.Property> get_property_list () {
	return (owned) this.property_list;
}

/* FIXME: it's a bit weird that this only returns things aren't classes
 * or properties, in terms of consistency. However this API is temporary
 * anyway, one day you will use Charango.Source API's to get this info
 */
public List<Charango.Entity> get_entity_list () {
	return (owned) this.entity_list;
}


/* FIXME: is it good to have a nullable type .. */
internal Charango.Entity? find_local_entity (string uri)
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

	if (this.ontology != null)
		if (uri == this.uri || (uri + "#") == this.uri || (uri + "/") == this.uri)
			return this.ontology;

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
	// There's no reason to ever need to move resources between namespaces
	warn_if_fail (old_entity.ns == new_entity.ns);

	if (new_entity.ns == this) {
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
	}

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

/*public override void dump () {
	print ("charango namespace: %s [%s]\n", uri.to_string(), prefix);

	foreach (Charango.Class rdfs_class in class_list) {
		assert (rdfs_class != null);
		print ("\tclass %i: ", 1); rdfs_class.dump();
	}
	foreach (Charango.Property rdfs_property in property_list) {
		print ("\tproperty %i: ", 1); rdfs_property.dump();
	}
}*/

}
