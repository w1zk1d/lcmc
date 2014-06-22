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

package lcmc.gui.dialog.host;

import javax.swing.JComponent;
import javax.swing.JPanel;
import javax.swing.SpringLayout;

import lcmc.data.Application;
import lcmc.data.Host;
import lcmc.data.drbd.DrbdInstallation;
import lcmc.gui.SpringUtilities;
import lcmc.gui.dialog.WizardDialog;
import lcmc.utilities.ConvertCmdCallback;
import lcmc.utilities.ExecCallback;
import lcmc.utilities.Tools;
import lcmc.utilities.ssh.ExecCommandConfig;
import lcmc.utilities.ssh.Ssh;

/**
 * An implementation of a dialog where heartbeat is installed.
 *
 * @author Rasto Levrinc
 * @version $Id$
 *
 */
final class HeartbeatInst extends DialogHost {
    /** Next dialog object. */
    private WizardDialog nextDialogObject = null;

    HeartbeatInst(final WizardDialog previousDialog,
                  final Host host,
                  final DrbdInstallation drbdInstallation) {
        super(previousDialog, host, drbdInstallation);
    }

    /**
     * Checks the answer of the installation and enables/disables the
     * components accordingly.
     */
    void checkAnswer(final String ans, final String installMethod) {
        // TODO: check if it really failes
        nextDialogObject = new CheckInstallation(getPreviousDialog().getPreviousDialog(),
                                                 getHost(),
                                                 getDrbdInstallation());
        progressBarDone();
        answerPaneSetText(Tools.getString("Dialog.Host.HeartbeatInst.InstOk"));
        enableComponents(new JComponent[]{buttonClass(backButton())});
        buttonClass(nextButton()).requestFocus();
        if (Tools.getApplication().getAutoOptionHost("hbinst") != null) {
            Tools.sleep(1000);
            pressNextButton();
        }
    }

    /** Inits the dialog and starts the installation procedure. */
    @Override
    protected void initDialogBeforeVisible() {
        super.initDialogBeforeVisible();
        enableComponentsLater(new JComponent[]{buttonClass(nextButton())});
    }

    /** Inits the dialog after it becomes visible. */
    @Override
    protected void initDialogAfterVisible() {
        installHeartbeat();
    }

    /** Installs the heartbeat. */
    private void installHeartbeat() {
        String arch = getHost().getDistString("HbPmInst.install."
                                              + getHost().getArch());
        if (arch == null) {
            arch = getHost().getArch();
        }
        final String archString = arch.replaceAll("i686", "i386");

        String installCommand = "HbPmInst.install";
        final String installMethod = getHost().getHeartbeatPacemakerInstallMethodIndex();
        if (installMethod != null) {
            installCommand = "HbPmInst.install." + installMethod;
        }
        Tools.getApplication().setLastHbPmInstalledMethod(
            getHost().getDistString("HbPmInst.install.text." + installMethod));
        Tools.getApplication().setLastInstalledClusterStack(
                                                Application.HEARTBEAT_NAME);

        getHost().execCommandInBash(new ExecCommandConfig()
                .commandString(installCommand)
                .progressBar(getProgressBar())
                .execCallback(new ExecCallback() {
                    @Override
                    public void done(final String answer) {
                        checkAnswer(answer, installMethod);
                    }

                    @Override
                    public void doneError(final String answer,
                                          final int errorCode) {
                        printErrorAndRetry(Tools.getString(
                                        "Dialog.Host.HeartbeatInst.InstError"),
                                answer,
                                errorCode);
                    }
                })
                .convertCmdCallback(new ConvertCmdCallback() {
                    @Override
                    public String convert(final String command) {
                        return command.replaceAll("@ARCH@",
                                archString);
                    }
                })
                .sshCommandTimeout(Ssh.DEFAULT_COMMAND_TIMEOUT_LONG));
    }

    /** Returns the next dialog. */
    @Override
    public WizardDialog nextDialog() {
        return nextDialogObject;
    }

    /**
     * Returns the description of the dialog defined as
     * Dialog.Host.HeartbeatInst.Description in TextResources.
     */
    @Override
    protected String getHostDialogTitle() {
        return Tools.getString("Dialog.Host.HeartbeatInst.Title");
    }

    /**
     * Returns the description of the dialog defined as
     * Dialog.Host.HeartbeatInst.Description in TextResources.
     */
    @Override
    protected String getDescription() {
        return Tools.getString("Dialog.Host.HeartbeatInst.Description");
    }

    /** Returns the input pane with info about the installation progress. */
    @Override
    protected JComponent getInputPane() {
        final JPanel pane = new JPanel(new SpringLayout());
        pane.add(getProgressBarPane());
        pane.add(getAnswerPane(
                     Tools.getString("Dialog.Host.HeartbeatInst.Executing")));
        SpringUtilities.makeCompactGrid(pane, 2, 1,  // rows, cols
                                              0, 0,  // initX, initY
                                              0, 0); // xPad, yPad

        return pane;
    }
}
