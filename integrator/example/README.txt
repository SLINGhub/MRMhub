INTEGRATOR — example input files
================================

The files in this folder are bundled into every INTEGRATOR release archive
(next to the MRMhub executable). They are the version-matched input templates:
their format can change together with the executable, so they ship with it.

To run INTEGRATOR, place these (edited for your data) and your mzML files next
to the executable, then run it. See the manual:
https://slinghub.github.io/MRMhub/integrator/

Files
-----
  param.txt         Processing parameters (this folder ships a template).
  run_order.csv     Acquisition order + sample roles (MAINTAINER: add the
                    version-matched template from the test dataset).
  feature_list.csv  Transition / assay list (MAINTAINER: add the
                    version-matched template from the test dataset).

The large demonstration mzML dataset is NOT stored in the repository; it is
downloaded from Zenodo and bundled into the separate "MRMhub-demo-*" archive.
