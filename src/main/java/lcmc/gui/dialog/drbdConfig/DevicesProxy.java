/*
 * This file is part of LCMC written by Rasto Levrinc.
 *
 * Copyright (C) 2013, Rastislav Levrinc.
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

package lcmc.gui.dialog.drbdConfig;

import lcmc.data.Host;
import lcmc.utilities.Tools;
import lcmc.gui.dialog.WizardDialog;
import lcmc.gui.dialog.host.Devices;
import lcmc.gui.resources.DrbdInfo;
import lcmc.gui.resources.DrbdVolumeInfo;
import lcmc.gui.resources.DrbdResourceInfo;
import javax.swing.JComponent;

/**
 * An implementation of a dialog where hardware information is collected.
 *
 * @author Rasto Levrinc
 * @version $Id$
 *
 */
final class DevicesProxy extends Devices {
    /** Serial version UID. */
    private static final long serialVersionUID = 1L;
    /** Drbd info. */
    private final DrbdInfo drbdInfo;
    /** Drbd volume info. */
    private final DrbdVolumeInfo drbdVolumeInfo;

    /** Prepares a new <code>Devices</code> object. */
    DevicesProxy(final WizardDialog previousDialog,
                 final Host host,
                 final DrbdInfo drbdInfo,
                 final DrbdVolumeInfo drbdVolumeInfo) {
        super(previousDialog, host);
        this.drbdInfo = drbdInfo;
        this.drbdVolumeInfo = drbdVolumeInfo;
    }

    @Override
    public WizardDialog nextDialog() {
        resetDrbdResourcePanel();
        //drbdInfo.addProxyHost(getHost());
        //return new Resource(this, drbdVolumeInfo);
        return new ProxyCheckInstallation(this,
                                          getHost(),
                                          drbdInfo,
                                          drbdVolumeInfo);
    }

    /**
     * Returns the title of the dialog. It is defined as
     * Dialog.Host.Devices.Title in TextResources.
     */
    @Override
    protected String getHostDialogTitle() {
        return Tools.getString("Dialog.Host.Devices.Title");
    }

    /**
     * Returns the description of the dialog. It is defined as
     * Dialog.Host.Devices.Description in TextResources.
     */
    @Override
    protected String getDescription() {
        return Tools.getString("Dialog.Host.Devices.Description");
    }

    private void resetDrbdResourcePanel() {
        if (drbdVolumeInfo != null) {
            final DrbdResourceInfo dri = drbdVolumeInfo.getDrbdResourceInfo();
            dri.resetInfoPanel();
            dri.getInfoPanel();
            dri.waitForInfoPanel();
            dri.selectMyself();
        }
    }

    /** Buttons that are enabled/disabled during checks. */
    @Override
    protected JComponent[] nextButtons() {
        return new JComponent[]{buttonClass(nextButton()),
                                buttonClass(finishButton())};
    }
}
