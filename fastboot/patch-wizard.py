#!/usr/bin/env python3
"""Apply SailFish startup-wizard QML patches to a rootfs tree.

usage: patch-wizard.py <rootfs-tree>       (the tree that contains usr/, etc/, ...)

Patch list (add new patches at the end):
  1. fingerprint step: drop the stale authentication token captured at the
     beginning of the wizard; the welcome dialog then takes the fresh
     re-authentication path (same as Settings), which is known to work.
  2. tutorial: skip the Tutorial entry page (it hangs on this port).
"""
import os
import shutil
import sys


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    root = sys.argv[1]
    path = os.path.join(root, "usr/share/jolla-startupwizard/main.qml")
    with open(path) as f:
        src = f.read()
    original = src

    def backup():
        b = path + ".bak-sfos530"
        if not os.path.exists(b):
            shutil.copy2(path, b)

    # 1) fingerprint: remove stale wizard authentication token
    old = (
        "            destination: _pageAfterFingerPrint ? _pageAfterFingerPrint : tutorialMainComponent\n"
        "            authenticationToken: root._fingerprintAuthenticationToken\n"
        "\n"
        "            settings: fingerprintSettings"
    )
    new = (
        "            destination: _pageAfterFingerPrint ? _pageAfterFingerPrint : tutorialMainComponent\n"
        "\n"
        "            settings: fingerprintSettings"
    )
    if old in src:
        backup()
        src = src.replace(old, new)

    # 2) tutorial: bypass broken TutorialEntryPage
    old = (
        "    readonly property Component tutorialMainComponent: {\n"
        '        var tutorial = Qt.createComponent(pageStack.resolveImportPage("Sailfish.Tutorial.TutorialEntryPage"))\n'
        "        if (tutorial.status != Component.Ready) {\n"
        '            console.log("No Tutorial installed, skipping.")\n'
        "            tutorial = noTutorialComponent\n"
        "        }\n"
        "\n"
        "        return tutorial\n"
        "    }"
    )
    new = "    readonly property Component tutorialMainComponent: noTutorialComponent"
    if old in src:
        backup()
        src = src.replace(old, new)

    # ---- future patches go here ----

    if src != original:
        with open(path, "w") as f:
            f.write(src)
        print("patched:", path)
    else:
        print("already patched, nothing to do")

    # sanity checks
    assert "fingerprintSettings.hasSensor" in src, "fingerprint branch missing"
    assert "readonly property Component tutorialMainComponent: noTutorialComponent" in src, "tutorial bypass missing"
    assert "authenticationToken: root._fingerprintAuthenticationToken" not in src, "stale token still present"
    print("verify OK")


if __name__ == "__main__":
    main()
