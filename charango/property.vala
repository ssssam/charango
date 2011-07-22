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

/**
 * Charango.Property:
 * 
 * Represents an Rdfs:Property or subproperty
 */
public class Charango.Property: Entity {

Ontology ontology;

public string name;
public string label;

/* type: basic type of literal stored by the property, or ValueBaseType.RESOURCE */
public Charango.ValueBaseType type;

/* range: actual range of the resource. Note that XSD literal types and derivations share
 *        an id space with RDFS classes.
 */
public Charango.Class range;

public Property (Ontology       owner,
                 string         uri,
                 Charango.Class rdf_type)
       throws Charango.ParseError {
	base (owner, uri, rdf_type);

	this.name = get_name_from_uri (uri);
}

public string to_string () {
	return "%s:%s".printf (ontology.prefix ?? ontology.uri, name);
}

public override void dump () {
	print ("rdf:Property '%s'\n", this.to_string());
}

}
