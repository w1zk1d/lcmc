/*
 * This file is part of LCMC written by Rasto Levrinc.
 *
 * Copyright (C) 2012-2013, Rastislav Levrinc.
 *
 * The LCMC is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * The LCMC is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with drbd; see the file COPYING.  If not, write to
 * the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 */

package lcmc;

import lcmc.utilities.Tools;
import lcmc.data.Host;

import lcmc.gui.dialog.WizardDialog;
import lcmc.gui.dialog.drbdConfig.NewProxyHost;
import lcmc.gui.resources.DrbdInfo;
import lcmc.gui.resources.DrbdVolumeInfo;


/**
 * Show step by step dialogs that add and configure new proxy host.
 *
 * @author Rasto Levrinc
 * @version $Id$
 */
public final class ProxyHostWizard {
    /** Whether the wizard was canceled. */
    private boolean canceled = false;
    private final DrbdInfo drbdInfo;
    private final DrbdVolumeInfo drbdVolumeInfo;
    private final Host host;


    /** Prepares new <code>ProxyHostWizard</code> object. */
    public ProxyHostWizard(final Host host,
                           final DrbdInfo drbdInfo,
                           final DrbdVolumeInfo drbdVolumeInfo) {
        this.host = host;
        this.drbdInfo = drbdInfo;
        this.drbdVolumeInfo = drbdVolumeInfo;
    }

    /** Shows step by step dialogs that add and configure new drbd resource. */
    public void showDialogs() {
        WizardDialog dialog =
                        new NewProxyHost(null, host, drbdInfo, drbdVolumeInfo);
        Tools.getGUIData().expandTerminalSplitPane(0);
        while (true) {
            final WizardDialog newdialog = (WizardDialog) dialog.showDialog();
            if (dialog.isPressedCancelButton()) {
                dialog.cancelDialog();
                canceled = true;
                Tools.getGUIData().expandTerminalSplitPane(1);
                return;
            } else if (dialog.isPressedFinishButton()) {
                break;
            }
            dialog = newdialog;
        }
    }

    /** Returns whether the wizard was canceled. */
    public boolean isCanceled() {
        return canceled;
    }
}
