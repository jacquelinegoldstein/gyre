! Module   : gyre_wos_bvp
! Purpose  : boundary-value solver (adiabatic)
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

module gyre_wos_bvp

  ! Uses

  use core_kinds

  use gyre_bvp
  use gyre_ext
  use gyre_ivp
  use gyre_ivp_factory
  use gyre_mode
  use gyre_mode_par
  use gyre_model
  use gyre_num_par
  use gyre_osc_par
  use gyre_sysmtx
  use gyre_sysmtx_factory
  use gyre_rot
  use gyre_rot_factory

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type, extends (r_bvp_t) :: wos_bvp_t
  end type wos_bvp_t

  ! Interfaces

  interface wos_bvp_t
     module procedure wos_bvp_t_
  end interface wos_bvp_t

  ! Access specifiers

  private

  public :: wos_bvp_t

  ! Procedures

contains

  function wos_bvp_t_ (x, c, np) result (bp)

    use gyre_wos_eqns
    use gyre_wos_bound

    real(WP), intent(in)                :: x(:)
    real(WP), intent(in)                :: c
    type(num_par_t), intent(in)         :: np
    type(wos_bvp_t), target             :: bp

    type(wos_eqns_t)                :: eq
    integer                        :: n
    real(WP)                       :: x_i
    real(WP)                       :: x_o
    type(wos_bound_t)               :: bd
    class(r_ivp_t), allocatable    :: iv
    class(r_sysmtx_t), allocatable :: sm

    ! Construct the wos_bvp_t

    ! Initialize the equations

    eq = wos_eqns_t(c)

    ! Initialize the boundary conditions

    n = SIZE(x)

    x_i = x(1)
    x_o = x(n)

    bd = wos_bound_t(x_i, x_o)

    ! Initialize the IVP solver

    allocate(iv, SOURCE=r_ivp_t(eq, np))

    ! Initialize the system matrix

    allocate(sm, SOURCE=r_sysmtx_t(n-1, eq%n_e, bd%n_i, bd%n_o, np))

    ! Initialize the bvp_t

    bp%r_bvp_t = r_bvp_t(x, NULL(), eq, bd, iv, sm)

    ! Finish

    return

  end function wos_bvp_t_

end module gyre_wos_bvp

