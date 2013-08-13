# File     : Make.inc
# Purpose  : standard makefile rules, targets

# The following flags can be edited (set to either yes or no)

# Enable debugging (with a performance penalty)
DEBUG=yes

# Enable OpenMP parallelization
OMP=yes

# Enable MPI parallelization
MPI=no

# Use double precision arithmetic (best left to 'yes')
DOUBLE_PRECISION=yes

############ DO NOT EDIT BELOW THIS LINE ############
### (unless you think you know what you're doing) ###
#####################################################

# Preprocesser flags

OPTS=DEBUG OMP MPI HDF5 DOUBLE_PRECISION 

FPX3FLAGS:=${FPX3FLAGS} -I.:${SUBDIRS} $(foreach opt,${OPTS},$(if $(filter yes,${${opt}}),-D${opt}))

# Compiler settings

export F9XC

ifeq (${MPI},yes)
  F9XC=mpif90
else
  F9XC=gfortran
endif

MODPATH=${MESASDK_ROOT}/include

FFLAGS:=${FFLAGS} -finit-real=snan -ffpe-trap=invalid,overflow,zero -fbacktrace

ifeq (${DEBUG},yes)
  FFLAGS:=${FFLAGS} -fcheck=all -Wall -Wno-unused-dummy-argument -finline-limit=0 -g
  FPX3FLAGS:=${FPX3FLAGS} -DLOG_LEVEL=DEBUG
else
  FFLAGS:=${FFLAGS} -O2 -march=native
  FPX3FLAGS:=${FPX3FLAGS} -DLOG_LEVEL=INFO
endif

F9XFLAGS:=${F9XFLAGS} $(addprefix -I,${MODPATH}) ${FFLAGS} -std=f2008
F77FLAGS:=${F77FLAGS} ${FFLAGS} -ffixed-form

ifeq (${OMP},yes)
  F9XFLAGS:=${F9XFLAGS} -fopenmp
  F77FLAGS:=${F77FLAGS} -fopenmp
endif

FPX3FLAGS:=${FPX3FLAGS} -DGFORTRAN_PR56218 -DGFORTRAN_PR57922 \
 -DGFORTRAN_PR53945 \
 -DGFORTRAN_PR_56052 -DGFORTRAN_PR_56872


LDFLAGS:=${LDFLAGS} `mesasdk_lapack95_link`

# Rules

vpath %.mod ${MODPATH}
vpath %.fpp ${SUBDIRS}
vpath %.inc ${SUBDIRS}
vpath %.f ${SUBDIRS}

.PRECIOUS : %.f90

%.o : %.mod

%.f90 : %.fpp
	@fpx3 ${FPX3FLAGS} < $< > $@

%.o %.mod : %.f90
	@echo FC $<
	@${F9XC} ${F9XFLAGS} ${MODINCS} -c $<
	@if [ -e $(basename $@).mod ]; then touch $(basename $@).mod; fi

%.o : %.f
	@echo FC $<
	@$(F9XC) ${F77FLAGS} -c $<

%.a :
	@echo AR $@
	@rm -f $@
	@${AR} crs $@ $^

% : %.o
	@echo LD $@
	@${F9XC} ${F9XFLAGS} -o $@ $^ ${LDFLAGS}

all : ${TARGETS}

install : ${TARGETS}
	for t in ${TARGETS}; do
	    cp ${TARGETS} ${DESTDIR}
	done

clean :
	rm -f ${TARGETS} $(addsuffix .f90,${TARGETS}) *.o *.mod .depend *.f90

# Dependencies

ifndef DEPEND_FILES
  DEPEND_FILES:=${TARGETS}
endif

ifneq ($(MAKECMDGOALS),clean)
-include .depend
endif

.depend :
	@echo Determining dependencies
	@fpx3_deps ${FPX3FLAGS} ${DEPEND_FILES} > .depend