/*
 * This file is part of DRBD Management Console by LINBIT HA-Solutions GmbH
 * written by Rasto Levrinc.
 *
 * Copyright (C) 2009, LINBIT HA-Solutions GmbH.
 * Copyright (C) 2011-2012, Rastislav Levrinc.
 *
 * DRBD Management Console is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * DRBD Management Console is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with drbd; see the file COPYING.  If not, write to
 * the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 */

package lcmc.utilities;

import lcmc.data.Value;

/**
 * This class provides unit object with short and long name for combo boxes.
 *
 * @author Rasto Levrinc
 * @version $Id$
 *
 */
public final class Unit implements Value {
    /** Short name. */
    private final String shortName;
    /** Secondary short name used for comparisons. */
    private final String secShortName;
    /** Name of the unit. */
    private final String name;
    /** Plural name of the unit. */
    private final String pluralName;
    /** Whether the unit should be in plural or not. */
    private boolean plural = true;
    /** Whether the field to which this unit belongs is empty. */
    private boolean empty = false;

    /** Prepares new <code>Unit</code> object. */
    public Unit(final String shortName,
                final String secShortName,
                final String name,
                final String pluralName) {
        this.shortName    = shortName;
        this.secShortName = secShortName;
        this.name         = name;
        this.pluralName   = pluralName;
    }

    /** Returns whether the unit should be in plural. */
    public boolean isPlural() {
        return plural;
    }

    /** Sets that the unit should be in plural. */
    public void setPlural(final boolean plural) {
        this.plural = plural;
    }

    /** Sets whether the field to which this unit belongs is empty. */
    public void setEmpty(final boolean empty) {
        this.empty = empty;
    }

    /** Returns whether the field to which this unit belongs is empty. */
    public boolean isEmpty() {
        return empty;
    }

    /** Returns the unit, plural if it should be in plural. */
    @Override
    public String toString() {
        if (empty) {
            return "";
        }
        if (plural) {
            return pluralName;
        }
        return name;
    }

    /** Returns short name of the unit. */
    public String getShortName() {
        if (empty) {
            return "";
        }
        return shortName;
    }

    /** Returns second short name of the unit. */
    public String getSecShortName() {
        return secShortName;
    }

    @Override
    public String getValueForGui() {
        return name;
    }

    @Override
    public String getValueForConfig() {
        return shortName;
    }

    @Override
    public boolean isNothingSelected() {
        return shortName == null;
    }

    @Override
    public Unit getUnit() {
        return null;
    }

    @Override
    public String getValueForConfigWithUnit() {
        return getValueForConfig();
    }

    @Override
    public boolean equals(Object obj) {
        if (obj == null) {
            return false;
        }
        if (getClass() != obj.getClass()) {
            return false;
        }
        final Unit other = (Unit) obj;
        if ((this.name == null) ? (other.name != null) : !this.name.equals(other.name)) {
            return false;
        }
        return true;
    }

    @Override
    public int hashCode() {
        int hash = 7;
        hash = 97 * hash + (this.name != null ? this.name.hashCode() : 0);
        return hash;
    }
}
