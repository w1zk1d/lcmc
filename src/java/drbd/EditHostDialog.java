/*
 * This file is part of DRBD Management Console by LINBIT HA-Solutions GmbH
 * written by Rasto Levrinc.
 *
 * Copyright (C) 2009, LINBIT HA-Solutions GmbH.
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


package drbd;

import drbd.data.Host;
import drbd.utilities.Tools;

import drbd.gui.dialog.host.DialogHost;
import drbd.gui.dialog.host.SSH;

/**
 * EditHostDialog.
 *
 * Show step by step dialogs that configure a host.
 *
 * @author Rasto Levrinc
 * @version $Id$
 */
public final class EditHostDialog {
    /** The host object. */
    private final Host host;

    /** Prepares a new <code>EditHostDialog</code> object. */
    public EditHostDialog(final Host host) {
        this.host = host;
    }

    /** Shows step by step dialogs that configure a host. */
    public void showDialogs() {
        DialogHost dialog = new SSH(null, host);
        Tools.getGUIData().expandTerminalSplitPane(0);
        while (true) {
            final DialogHost newdialog = (DialogHost) dialog.showDialog();
            if (dialog.isPressedCancelButton()) {
                Tools.getGUIData().expandTerminalSplitPane(1);
                return;
            } else if (dialog.isPressedFinishButton()) {
                break;
            }
            dialog = newdialog;
        }
        Tools.getGUIData().expandTerminalSplitPane(1);
    }
}