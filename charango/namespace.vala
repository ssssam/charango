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

/* Applications can access the source for free, but they must keep track of
 * the store interface (if there is one) themselves. Internally we keep track
 * inside the namespace :)
 */
public Charango.Source source;
internal Charango.Store store;

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

public Namespace (Context context,
                  string  uri,
                  string? prefix)
       throws RdfError {
	unichar terminator = uri[uri.length-1];
	if (terminator != '#' && terminator != '/')
		throw new RdfError.URI_PARSE_ERROR ("Namespace must end in # or /; got '%s'", uri);

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
	catch (RdfError e) { warning (e.message); }

	this.builtin = true;
}

internal void replace_entity (Entity old_entity,
                              Entity new_entity) {
	// There's no reason to ever need to move resources between namespaces
	warn_if_fail (old_entity.ns == new_entity.ns);

	if (new_entity.ns == this) {
		if (this.ontology == old_entity)
			this.ontology = (Ontology)new_entity;

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
