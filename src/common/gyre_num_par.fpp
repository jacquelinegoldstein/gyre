! Module   : gyre_num_par
! Purpose  : numerics parameters
!
! Copyright 2013-2015 Rich Townsend
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
$include 'core_parallel.inc'

module gyre_num_par

  ! Uses

  use core_kinds
  use core_parallel

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type :: num_par_t
     integer         :: n_iter_max
     logical         :: deflate_roots
     logical         :: restrict_roots
     character(64)   :: ivp_solver
     character(64)   :: r_root_solver
     character(64)   :: c_root_solver
     character(64)   :: matrix_type
     character(2048) :: tag_list
  end type num_par_t

  ! Interfaces

  $if ($MPI)

  interface bcast
     module procedure bcast_0_
     module procedure bcast_1_
  end interface bcast

  interface bcast_alloc
     module procedure bcast_alloc_0_
     module procedure bcast_alloc_1_
  end interface bcast_alloc

  $endif

  ! Access specifiers

  private

  public :: num_par_t
  public :: read_num_par
  $if ($MPI)
  public :: bcast
  public :: bcast_alloc
  $endif

  ! Procedures

contains

  subroutine read_num_par (unit, nm_p)

    integer, intent(in)                       :: unit
    type(num_par_t), allocatable, intent(out) :: nm_p(:)

    integer                            :: n_nm_p
    integer                            :: i
    integer                            :: n_iter_max
    logical                            :: deflate_roots
    logical                            :: restrict_roots
    character(LEN(nm_p%ivp_solver))    :: ivp_solver
    character(LEN(nm_p%r_root_solver)) :: r_root_solver
    character(LEN(nm_p%c_root_solver)) :: c_root_solver
    character(LEN(nm_p%matrix_type))   :: matrix_type
    character(LEN(nm_p%tag_list))      :: tag_list

    namelist /num/ n_iter_max, deflate_roots, restrict_roots, &
         ivp_solver, r_root_solver, c_root_solver, matrix_type, tag_list

    ! Count the number of num namelists

    rewind(unit)

    n_nm_p = 0

    count_loop : do
       read(unit, NML=num, END=100)
       n_nm_p = n_nm_p + 1
    end do count_loop

100 continue

    ! Read numerical parameters

    rewind(unit)

    allocate(nm_p(n_nm_p))

    read_loop : do i = 1,n_nm_p

       n_iter_max = 50

       deflate_roots = .TRUE.
       restrict_roots = .TRUE.

       ivp_solver = 'COLLOC_GL2'

       r_root_solver = 'BRENT'
       c_root_solver = 'RIDDERS'

       matrix_type = 'BLOCK'
       tag_list = ''

       read(unit, NML=num)

       ! Initialize the num_par

       nm_p(i) = num_par_t(n_iter_max=n_iter_max, &
                           deflate_roots=deflate_roots, &
                           restrict_roots=restrict_roots, &
                           ivp_solver=ivp_solver, &
                           r_root_solver=r_root_solver, &
                           c_root_solver=c_root_solver, &
                           matrix_type=matrix_type, &
                           tag_list=tag_list)

    end do read_loop

    ! Finish

    return

  end subroutine read_num_par

!****

  $if ($MPI)

  $define $BCAST $sub

  $local $RANK $1

  subroutine bcast_${RANK}_ (nm_p, root_rank)

    type(num_par_t), intent(inout) :: nm_p$ARRAY_SPEC($RANK)
    integer, intent(in)            :: root_rank

    ! Broadcast the num_par_t

    call bcast(nm_p%n_iter_max, root_rank)

    call bcast(nm_p%deflate_roots, root_rank)
    call bcast(nm_p%restrict_roots, root_rank)
 
    call bcast(nm_p%ivp_solver, root_rank)

    call bcast(nm_p%r_root_solver, root_rank)
    call bcast(nm_p%c_root_solver, root_rank)

    call bcast(nm_p%matrix_type, root_rank)

    call bcast(nm_p%tag_list, root_rank)

    ! Finish

    return

  end subroutine bcast_${RANK}_

  $endsub

  $BCAST(0)
  $BCAST(1)

!****

  $BCAST_ALLOC(type(num_par_t),0)
  $BCAST_ALLOC(type(num_par_t),1)

  $endif

end module gyre_num_par
