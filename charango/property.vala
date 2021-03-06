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

public Property (Charango.Namespace ns,
                 string             uri,
                 Charango.Class     rdf_type)
       throws Charango.RdfError {
	base (ns, uri, rdf_type);
}

public Property.prototype (Charango.Namespace ns,
                           string             uri) {
	base.prototype (ns, uri);
}

}
