! Program  : gyre_contour
! Purpose  : discriminant contouring code
!
! Copyright 2014-2020 Rich Townsend & The GYRE Team
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

program gyre_contour

  ! Uses

  use core_kinds
  use core_hgroup
  use core_order
  use core_parallel
  use core_system

  use gyre_bvp
  use gyre_constants
  use gyre_context
  use gyre_contour_map
  use gyre_contour_path
  use gyre_detail
  use gyre_discrim_func
  use gyre_ext
  use gyre_grid
  use gyre_grid_factory
  use gyre_grid_par
  use gyre_math
  use gyre_mode
  use gyre_mode_par
  use gyre_model
  use gyre_model_factory
  use gyre_model_par
  use gyre_nad_bvp
  use gyre_num_par
  use gyre_osc_par
  use gyre_out_par
  use gyre_root
  use gyre_rot_par
  use gyre_scan
  use gyre_scan_par
  use gyre_state
  use gyre_status
  use gyre_summary
  use gyre_util
  use gyre_version
  use gyre_wave

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Variables

  character(:), allocatable         :: filename
  integer                           :: unit
  type(model_par_t)                 :: ml_p
  type(mode_par_t), allocatable     :: md_p(:)
  type(osc_par_t), allocatable      :: os_p(:)
  type(rot_par_t), allocatable      :: rt_p(:)
  type(num_par_t), allocatable      :: nm_p(:)
  type(grid_par_t), allocatable     :: gr_p(:)
  type(scan_par_t), allocatable     :: sc_p(:)
  type(out_par_t)                   :: ot_p
  character(FILENAME_LEN)           :: map_file
  logical                           :: include_paths
  class(model_t), pointer           :: ml => null()
  type(osc_par_t)                   :: os_p_sel
  type(rot_par_t)                   :: rt_p_sel
  type(num_par_t)                   :: nm_p_sel
  type(grid_par_t)                  :: gr_p_sel
  type(scan_par_t), allocatable     :: sc_p_sel(:)
  type(context_t), pointer          :: cx => null()
  type(summary_t)                   :: sm
  type(detail_t)                    :: dt
  real(WP), allocatable             :: omega_re(:)
  real(WP), allocatable             :: omega_im(:)
  real(WP)                          :: omega_min
  real(WP)                          :: omega_max
  type(grid_t)                      :: gr
  type(nad_bvp_t), target           :: bp
  type(c_state_t)                   :: st
  type(c_discrim_func_t)            :: df
  type(contour_map_t)               :: cm
  type(contour_path_t), allocatable :: cp_re(:)
  type(contour_path_t), allocatable :: cp_im(:)

  ! Read command-line arguments

  $ASSERT(n_arg() == 1,Syntax: gyre_map <filename>)

  call get_arg(1, filename)

  ! Initialize

  call init_parallel()
  call init_math()

  call set_log_level($str($LOG_LEVEL))

  if (check_log_level('INFO')) then

     write(OUTPUT_UNIT, 100) form_header('gyre_contour ['//VERSION//']', '=')
100  format(A)

     if (check_log_level('DEBUG')) then
        write(OUTPUT_UNIT, 110) 'Compiler         :', COMPILER_VERSION()
        write(OUTPUT_UNIT, 110) 'Compiler options :', COMPILER_OPTIONS()
110     format(A,1X,A)
     endif

     write(OUTPUT_UNIT, 120) 'OpenMP Threads   :', OMP_SIZE_MAX
     write(OUTPUT_UNIT, 120) 'MPI Processors   :', MPI_SIZE
120  format(A,1X,I0)
     
     write(OUTPUT_UNIT, 110) 'Input filename   :', filename
     write(OUTPUT_UNIT, 110) 'GYRE_DIR         :', gyre_dir

     write(OUTPUT_UNIT, 100) form_header('Initialization', '=')

  endif

  ! Process arguments

  open(NEWUNIT=unit, FILE=filename, STATUS='OLD')

  call read_constants(unit)

  call read_model_par(unit, ml_p)
  call read_mode_par(unit, md_p)
  call read_osc_par(unit, os_p)
  call read_rot_par(unit, rt_p)
  call read_num_par(unit, nm_p)
  call read_grid_par(unit, gr_p)
  call read_scan_par(unit, sc_p)
  call read_out_par(unit, 'nad', ot_p)
  call read_map_par(unit, map_file, include_paths)

  $ASSERT(SIZE(md_p) == 1,Must be exactly one mode parameter)

  ! Initialize the model

  ml => model_t(ml_p)

  ! Select parameters according to tags

  call select_par(os_p, md_p(1)%tag, os_p_sel)
  call select_par(rt_p, md_p(1)%tag, rt_p_sel)
  call select_par(nm_p, md_p(1)%tag, nm_p_sel)
  call select_par(gr_p, md_p(1)%tag, gr_p_sel)
  call select_par(sc_p, md_p(1)%tag, sc_p_sel)
  
  ! Create the context

  allocate(cx, SOURCE=context_t(ml, gr_p_sel, md_p(1), os_p_sel, rt_p_sel))

  ! Initialize the summary and detail outputters

  sm = summary_t(ot_p)
  dt = detail_t(ot_p)

  ! Set up the frequency arrays

  call build_scan(cx, md_p(1), os_p_sel, sc_p_sel, omega_re, 'REAL')
  $ASSERT(SIZE(omega_re) >= 1,Real axis too short)
  call build_scan(cx, md_p(1), os_p_sel, sc_p_sel, omega_im, 'IMAG')
  $ASSERT(SIZE(omega_re) >= 1,Imaginary axis too short)

  ! Create the grid

  gr = grid_t(cx, omega_re, gr_p_sel, os_p_sel)

  ! Set frequency bounds

  if (nm_p_sel%restrict_roots) then
     omega_min = MINVAL(omega_re)
     omega_max = MAXVAL(omega_re)
  else
     omega_min = -HUGE(0._WP)
     omega_max = HUGE(0._WP)
  endif

  ! Set up the bvp

  bp = nad_bvp_t(cx, gr, md_p(1), nm_p_sel, os_p_sel)

  ! Set up the discriminant function

  st = c_state_t(omega=0._WP, omega_r=0._WP)
  df = c_discrim_func_t(bp, st, omega_min, omega_max)

  ! Evaluate the contour map

  call eval_map(omega_re, omega_im, cm)

  ! (Next steps are root rank only)

  if (MPI_RANK == 0) then

     ! Trace the paths

     call cm%trace_paths(cp_re, cp_im, process_isect)

     ! Write the map

     if (include_paths) then
        call write_map(map_file, cm, cp_re, cp_im)
     else
        call write_map(map_file, cm)
     endif

     ! Write the summary

     call sm%write()

  end if

  ! Finish

  call final_parallel()

contains

  subroutine read_map_par (unit, map_file, include_paths)

    integer, intent(in)       :: unit
    character(*), intent(out) :: map_file
    logical, intent(out)      :: include_paths

    namelist /map_output/ map_file, include_paths

    ! Read output parameters

    rewind(unit)

    read(unit, NML=map_output)

    ! Finish
    
    return

  end subroutine read_map_par
          
  !****

  subroutine eval_map (omega_re, omega_im, cm)

    real(WP), intent(in)             :: omega_re(:)
    real(WP), intent(in)             :: omega_im(:)
    type(contour_map_t), intent(out) :: cm

    integer                    :: n_omega_re
    integer                    :: n_omega_im
    integer, allocatable       :: k_part(:)
    integer                    :: n_percent
    integer                    :: k
    integer                    :: i(2)
    complex(WP)                :: omega
    type(c_ext_t)              :: discrim
    integer                    :: i_percent
    integer                    :: status
    complex(WP), allocatable   :: discrim_map_f(:,:)
    integer, allocatable       :: discrim_map_e(:,:)
    $if ($MPI)
    integer                    :: p
    $endif
    type(c_ext_t), allocatable :: discrim_map(:,:)

    ! Map the discriminant

    n_omega_re = SIZE(omega_re)
    n_omega_im = SIZE(omega_im)

    allocate(discrim_map_f(n_omega_re,n_omega_im))
    allocate(discrim_map_e(n_omega_re,n_omega_im))

    allocate(k_part(MPI_SIZE+1))

    call partition_tasks(n_omega_re*n_omega_im, 1, k_part)

    n_percent = 0

    do k = k_part(MPI_RANK+1), k_part(MPI_RANK+2)-1

       i = index_nd(k, [n_omega_re,n_omega_im])

       omega = CMPLX(omega_re(i(1)), omega_im(i(2)), KIND=WP)

       if (MPI_RANK == 0) then
          i_percent = FLOOR(100._WP*REAL(k-k_part(MPI_RANK+1))/REAL(k_part(MPI_RANK+2)-k_part(MPI_RANK+1)-1))
          if (i_percent > n_percent) then
             print *,'Percent complete: ', i_percent
             n_percent = i_percent
          end if
       endif

       call df%eval(c_ext_t(omega), discrim, status)
       $ASSERT(status == STATUS_OK,Invalid status)

       discrim_map_f(i(1),i(2)) = FRACTION(discrim)
       discrim_map_e(i(1),i(2)) = EXPONENT(discrim)

    end do

    $if ($MPI)

    do p = 1,MPI_SIZE
       call bcast_seq(discrim_map_f, k_part(p), k_part(p+1)-1, p-1)
       call bcast_seq(discrim_map_e, k_part(p), k_part(p+1)-1, p-1)
    end do

    $endif

    discrim_map = scale(c_ext_t(discrim_map_f), discrim_map_e)

    ! Create the contour map

    cm = contour_map_t(omega_re, omega_im, discrim_map)

    ! Finish

    return

  end subroutine eval_map

  !****

  subroutine process_isect (omega_a_re, omega_b_re, omega_a_im, omega_b_im)

    complex(WP), intent(in) :: omega_a_re
    complex(WP), intent(in) :: omega_b_re
    complex(WP), intent(in) :: omega_a_im
    complex(WP), intent(in) :: omega_b_im

    type(c_ext_t) :: omega_re
    type(c_ext_t) :: omega_im
    type(c_ext_t) :: discrim_re
    type(c_ext_t) :: discrim_im
    type(c_ext_t) :: omega_root
    integer       :: status
    integer       :: n_iter
    integer, save :: j = 0
    type(wave_t)  :: wv
    type(mode_t)  :: md
    type(r_ext_t) :: chi

    ! Set up the initial trial frequencies from the real and imag zero
    ! contours

    omega_re = omega_init(c_ext_t(omega_a_re), c_ext_t(omega_b_re), 'im')
    omega_im = omega_init(c_ext_t(omega_a_im), c_ext_t(omega_b_im), 're')

    call df%eval(omega_re, discrim_re, status)
    if (status /= STATUS_OK) then
       call report_status(status, 'initial guess (re)')
       return
    endif

    call df%eval(omega_im, discrim_im, status)
    if (status /= STATUS_OK) then
       call report_status(status, 'initial guess (im)')
       return
    endif

    ! Find the discriminant root

    call solve(df, nm_p_sel, omega_re, omega_im, r_ext_t(0._WP), omega_root, status, &
               n_iter=n_iter, n_iter_max=nm_p_sel%n_iter_max, f_cx_a=discrim_re, f_cx_b=discrim_im)
    if (status /= STATUS_OK) then
       call report_status(status, 'solve')
       return
    end if

    ! Construct the mode_t

    j = j + 1

    st = c_state_t(omega=cmplx(omega_root), omega_r=0._WP)

    wv = wave_t(bp, st, j)
    md = mode_t(wv)

    ! Cache/write it

    chi = abs(md%discrim)/max(abs(discrim_re), abs(discrim_im))
    
    if (check_log_level('INFO')) then
       write(OUTPUT_UNIT, 100) md%l, md%m, md%n_pg, md%n_p, md%n_g, &
            md%omega, real(chi), n_iter
100    format(1X,I3,1X,I4,1X,I7,1X,I6,1X,I6,1X,E15.8,1X,E15.8,1X,E10.4,1X,I6)
    endif


    call sm%cache(md)
    call dt%write(md)

    ! Finish

    return

  end subroutine process_isect

  !***

  function omega_init (omega_a, omega_b, part)

    type(c_ext_t), intent(in) :: omega_a
    type(c_ext_t), intent(in) :: omega_b
    character(*), intent(in)  :: part
    type(c_ext_t)             :: omega_init

    type(c_ext_t) :: discrim_a
    type(c_ext_t) :: discrim_b
    integer       :: status
    type(r_ext_t) :: w

    call df%eval(omega_a, discrim_a, status)
    $ASSERT(status == STATUS_OK,Invalid status)

    call df%eval(omega_b, discrim_b, status)
    $ASSERT(status == STATUS_OK,Invalid status)

    ! Look for the point on the segment where the real/imaginary
    ! part of the discriminant changes sign

    select case (part)
    case ('re')
       w = -real_part(discrim_a)/(real_part(discrim_b) - real_part(discrim_a))
    case ('im')
       w = -imag_part(discrim_a)/(imag_part(discrim_b) - imag_part(discrim_a))
    case default
       $ABORT(Invalid part)
    end select
    
    omega_init = (1._WP-w)*omega_a + w*omega_b

    ! Finish

    return

  end function omega_init

  !****

  subroutine write_map (map_file, cm, cp_re, cp_im)

    character(*), intent(in)                   :: map_file
    type(contour_map_t), intent(in)            :: cm
    type(contour_path_t), intent(in), optional :: cp_re(:)
    type(contour_path_t), intent(in), optional :: cp_im(:)

    type(hgroup_t) :: hg
    type(hgroup_t) :: hg_cp
    integer        :: i_cp

    ! Write the contour map

    if (map_file /= '') then

       hg = hgroup_t(map_file, CREATE_FILE)

       call write(hg, cm)

       if (PRESENT(cp_re)) then

          call write_attr(hg, 'n_cp_re', SIZE(cp_re))

          do i_cp = 1, SIZE(cp_re)
             hg_cp = hgroup_t(hg, elem_group_name('path-re', [i_cp]))
             call write(hg_cp, cp_re(i_cp))
             call hg_cp%final()
          end do

       endif

       if (PRESENT(cp_im)) then

          call write_attr(hg, 'n_cp_im', SIZE(cp_im))

          do i_cp = 1, SIZE(cp_im)
             hg_cp = hgroup_t(hg, elem_group_name('path-im', [i_cp]))
             call write(hg_cp, cp_im(i_cp))
             call hg_cp%final()
          end do
          
       endif

       call hg%final()

    end if

    ! Finish

    return

  end subroutine write_map

  !****

  subroutine report_status (status, stage_str)

    integer, intent(in)      :: status
    character(*), intent(in) :: stage_str

    ! Report the status

    if (check_log_level('WARN')) then

       write(OUTPUT_UNIT, 100) 'Failed during ', stage_str, ' : ', status_str(status)
100    format(4A)

    endif
      
    ! Finish

    return

  end subroutine report_status

end program gyre_contour
