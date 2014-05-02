! Program  : gyre_ad
! Purpose  : adiabatic oscillation code
!
! Copyright 2013 Rich Townsend
!
! This file is part of GYRE. GYRE is free software: you can
! redistribute it and/or modify it under the terms of the GNU General
! Public License as published by the Free Software Foundation, version 3.
!
! GYRE is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
! or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
! License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

$include 'core.inc'

program gyre_ad

  ! Uses

  use core_kinds, SP_ => SP
  use gyre_constants
  use core_parallel

  use gyre_version
  use gyre_model
  $if ($MPI)
  use gyre_model_mpi
  $endif
  use gyre_modepar
  use gyre_oscpar
  use gyre_numpar
  use gyre_gridpar
  use gyre_scanpar
  use gyre_bvp
  use gyre_ad_bvp
  use gyre_rad_bvp
  use gyre_search
  use gyre_mode
  use gyre_input
  use gyre_output
  use gyre_util

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Variables

  character(LEN=:), allocatable :: filename
  integer                       :: unit
  real(WP), allocatable         :: x_ml(:)
  class(model_t), pointer       :: ml => null()
  type(modepar_t), allocatable  :: mp(:)
  type(oscpar_t), allocatable   :: op(:)
  type(numpar_t), allocatable   :: np(:)
  type(gridpar_t), allocatable  :: shoot_gp(:)
  type(gridpar_t), allocatable  :: recon_gp(:)
  type(scanpar_t), allocatable  :: sp(:)
  integer                       :: i
  type(oscpar_t), allocatable   :: op_sel(:)
  type(numpar_t), allocatable   :: np_sel(:)
  type(gridpar_t), allocatable  :: shoot_gp_sel(:)
  type(gridpar_t), allocatable  :: recon_gp_sel(:)
  type(scanpar_t), allocatable  :: sp_sel(:)
  real(WP), allocatable         :: omega(:)
  class(bvp_t), allocatable     :: bp
  type(mode_t), allocatable     :: md(:)
  type(mode_t), allocatable     :: md_all(:)
  type(mode_t), allocatable     :: md_tmp(:)

  ! Initialize

  call init_parallel()

  call set_log_level($str($LOG_LEVEL))

  if (check_log_level('INFO')) then

     write(OUTPUT_UNIT, 100) form_header('gyre_ad ['//TRIM(version)//']', '=')
100  format(A)

     write(OUTPUT_UNIT, 110) 'Compiler         :', COMPILER_VERSION()
     write(OUTPUT_UNIT, 110) 'Compiler options :', COMPILER_OPTIONS()
110  format(A,1X,A)

     write(OUTPUT_UNIT, 120) 'OpenMP Threads   :', OMP_SIZE_MAX
     write(OUTPUT_UNIT, 120) 'MPI Processors   :', MPI_SIZE
120  format(A,1X,I0)

     write(OUTPUT_UNIT, 100) form_header('Initialization', '=')

  endif

  ! Process arguments

  if (MPI_RANK == 0) then

     call parse_args(filename)
     
     open(NEWUNIT=unit, FILE=filename, STATUS='OLD')

     call read_constants(unit)
     call read_model(unit, x_ml, ml)
     call read_modepar(unit, mp)
     call read_oscpar(unit, op)
     call read_numpar(unit, np)
     call read_shoot_gridpar(unit, shoot_gp)
     call read_recon_gridpar(unit, recon_gp)
     call read_scanpar(unit, sp)

  end if

  $if ($MPI)
  call bcast_constants(0)
  call bcast_alloc(x_ml, 0)
  call bcast_alloc(ml, 0)
  call bcast_alloc(mp, 0)
  call bcast_alloc(op, 0)
  call bcast_alloc(np, 0)
  call bcast_alloc(shoot_gp, 0)
  call bcast_alloc(recon_gp, 0)
  call bcast_alloc(sp, 0)
  $endif

  ! Loop through modepars

  allocate(md_all(0))

  op_loop : do i = 1, SIZE(mp)

     if (check_log_level('INFO')) then

        write(OUTPUT_UNIT, 100) form_header('Mode Search', '=')

        write(OUTPUT_UNIT, 100) 'Mode parameters'

        write(OUTPUT_UNIT, 130) 'l :', mp(i)%l
        write(OUTPUT_UNIT, 130) 'm :', mp(i)%m
130     format(2X,A,1X,I0)

        write(OUTPUT_UNIT, *)

     endif

     ! Select parameters according to tags

     call select_par(op, mp(i)%tag, op_sel, last=.TRUE.)
     call select_par(np, mp(i)%tag, np_sel, last=.TRUE.)
     call select_par(shoot_gp, mp(i)%tag, shoot_gp_sel)
     call select_par(recon_gp, mp(i)%tag, recon_gp_sel)
     call select_par(sp, mp(i)%tag, sp_sel)

     $ASSERT(SIZE(op_sel) == 1,No matching osc parameters)
     $ASSERT(SIZE(np_sel) == 1,No matching num parameters)
     $ASSERT(SIZE(shoot_gp_sel) >= 1,No matching shoot_grid parameters)
     $ASSERT(SIZE(recon_gp_sel) >= 1,No matching recon_grid parameters)
     $ASSERT(SIZE(sp_sel) >= 1,No matching scan parameters)

     ! Set up the frequency array

     call build_scan(sp_sel, ml, mp(i), op_sel(1), shoot_gp_sel, x_ml, omega)

     ! Store the frequency range in shoot_gp_sel

     shoot_gp_sel%omega_a = MINVAL(omega)
     shoot_gp_sel%omega_b = MAXVAL(omega)

     ! Set up bp

     if (ALLOCATED(bp)) deallocate(bp)

     if (mp(i)%l == 0 .AND. np_sel(1)%reduce_order) then
        allocate(bp, SOURCE=rad_bvp_t(ml, mp(i), op_sel(1), np_sel(1), shoot_gp_sel, recon_gp_sel, x_ml))
     else
        allocate(bp, SOURCE=ad_bvp_t(ml, mp(i), op_sel(1), np_sel(1), shoot_gp_sel, recon_gp_sel, x_ml))
     endif

     ! Find modes

     call scan_search(bp, omega, md)

     ! (The following could be simpler, but this is a workaround for a
     ! gfortran issue, likely PR 57839)

     md_tmp = [md_all, md]
     call MOVE_ALLOC(md_tmp, md_all)

     deallocate(bp)

  end do op_loop

  ! Write output
 
  if (MPI_RANK == 0) then
     call write_data(unit, md_all)
  endif

  ! Finish

  close(unit)

  call final_parallel()

end program gyre_ad
