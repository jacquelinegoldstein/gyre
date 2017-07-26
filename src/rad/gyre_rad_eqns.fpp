! Module   : gyre_rad_eqns
! Purpose  : radial adiabatic differential equations
!
! Copyright 2013-2017 Rich Townsend
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

module gyre_rad_eqns

  ! Uses

  use core_kinds

  use gyre_eqns
  use gyre_model
  use gyre_model_util
  use gyre_mode_par
  use gyre_osc_par
  use gyre_point
  use gyre_rad_share
  use gyre_rad_trans

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Parameter definitions

  integer, parameter :: J_V_G = 1
  integer, parameter :: J_AS = 2
  integer, parameter :: J_U = 3
  integer, parameter :: J_C_1 = 4
  integer, parameter :: J_OMEGA_ROT = 5

  integer, parameter :: J_LAST = J_OMEGA_ROT

  ! Derived-type definitions

  type, extends (r_eqns_t) :: rad_eqns_t
     private
     type(rad_share_t), pointer  :: sh => null()
     type(rad_trans_t)           :: tr
     real(WP), allocatable       :: coeff(:,:)
     real(WP), allocatable       :: x(:)
     real(WP)                    :: alpha_om
   contains
     private
     procedure, public :: stencil
     procedure, public :: A
     procedure, public :: xA
  end type rad_eqns_t

  ! Interfaces

  interface rad_eqns_t
     module procedure rad_eqns_t_
  end interface rad_eqns_t

  ! Access specifiers

  private

  public :: rad_eqns_t

  ! Procedures

contains

  function rad_eqns_t_ (sh, pt_i, md_p, os_p) result (eq)

    class(rad_share_t), pointer, intent(in) :: sh
    type(point_t), intent(in)               :: pt_i
    type(mode_par_t), intent(in)            :: md_p
    type(osc_par_t), intent(in)             :: os_p
    type(rad_eqns_t)                        :: eq

    ! Construct the rad_eqns_t

    eq%sh => sh

    eq%tr = rad_trans_t(sh, pt_i, md_p, os_p)

    select case (os_p%time_factor)
    case ('OSC')
       eq%alpha_om = 1._WP
    case ('EXP')
       eq%alpha_om = -1._WP
    case default
       $ABORT(Invalid time_factor)
    end select

    eq%n_e = 2

    ! Finish

    return

  end function rad_eqns_t_

  !****

  subroutine stencil (this, pt)

    class(rad_eqns_t), intent(inout) :: this
    type(point_t), intent(in)        :: pt(:)

    integer :: n_s
    integer :: i

    ! Calculate coefficients at the stencil points

    associate (ml => this%sh%ml)

      call check_model(ml, [I_V_2,I_AS,I_U,I_C_1,I_GAMMA_1,I_OMEGA_ROT])

      n_s = SIZE(pt)
      
      if (ALLOCATED(this%coeff)) deallocate(this%coeff)
      allocate(this%coeff(n_s,J_LAST))

      do i = 1, n_s
         this%coeff(i,J_V_G) = ml%coeff(I_V_2, pt(i))*pt(i)%x**2/ml%coeff(I_GAMMA_1, pt(i))
         this%coeff(i,J_AS) = ml%coeff(I_AS, pt(i))
         this%coeff(i,J_U) = ml%coeff(I_U, pt(i))
         this%coeff(i,J_C_1) = ml%coeff(I_C_1, pt(i))
         this%coeff(i,J_OMEGA_ROT) = ml%coeff(I_OMEGA_ROT, pt(i))
      end do

      this%x = pt%x

    end associate

    ! Set up stencil for the tr component

    call this%tr%stencil(pt)

    ! Finish

    return

  end subroutine stencil

  !****

  function A (this, i, omega)

    class(rad_eqns_t), intent(in) :: this
    integer, intent(in)           :: i
    real(WP), intent(in)          :: omega
    real(WP)                      :: A(this%n_e,this%n_e)
    
    ! Evaluate the RHS matrix

    A = this%xA(i, omega)/this%x(i)

    ! Finish

    return

  end function A

  !****

  function xA (this, i, omega)

    class(rad_eqns_t), intent(in) :: this
    integer, intent(in)           :: i
    real(WP), intent(in)          :: omega
    real(WP)                      :: xA(this%n_e,this%n_e)

    real(WP) :: omega_c
    
    ! Evaluate the log(x)-space RHS matrix

    associate ( &
         V_g => this%coeff(i,J_V_G), &
         As => this%coeff(i,J_AS), &
         U => this%coeff(i,J_U), &
         c_1 => this%coeff(i,J_C_1), &
         Omega_rot => this%coeff(i,J_OMEGA_ROT), &
         alpha_om => this%alpha_om)

      omega_c = this%sh%omega_c(Omega_rot, omega)

      ! Set up the matrix

      xA(1,1) = V_g - 1._WP
      xA(1,2) = -V_g
      
      xA(2,1) = c_1*alpha_om*omega_c**2 + U - As
      xA(2,2) = As - U + 3._WP

    end associate

    ! Apply the variables transformation

    call this%tr%trans_eqns(xA, i, omega)

    ! Finish

    return

  end function xA

end module gyre_rad_eqns
