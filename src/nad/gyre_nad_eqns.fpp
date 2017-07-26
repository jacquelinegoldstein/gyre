! Module   : gyre_nad_eqns
! Purpose  : nonadiabatic differential equations
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

module gyre_nad_eqns

  ! Uses

  use core_kinds

  use gyre_eqns
  use gyre_linalg
  use gyre_model
  use gyre_mode_par
  use gyre_model_util
  use gyre_nad_share
  use gyre_nad_trans
  use gyre_osc_par
  use gyre_point

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Parameter definitions

  integer, parameter :: P1_CONV_SCHEME = 1
  integer, parameter :: P4_CONV_SCHEME = 4

  integer, parameter :: J_V = 1
  integer, parameter :: J_V_G = 2
  integer, parameter :: J_As = 3
  integer, parameter :: J_U = 4
  integer, parameter :: J_C_1 = 5
  integer, parameter :: J_DELTA = 6
  integer, parameter :: J_NABLA_AD = 7
  integer, parameter :: J_DNABLA_AD = 8
  integer, parameter :: J_NABLA = 9
  integer, parameter :: J_C_LUM = 10
  integer, parameter :: J_DC_LUM = 11
  integer, parameter :: J_C_RAD = 12
  integer, parameter :: J_DC_RAD = 13
  integer, parameter :: J_C_DIF = 14
  integer, parameter :: J_C_THN = 15
  integer, parameter :: J_DC_THN = 16
  integer, parameter :: J_C_THK = 17
  integer, parameter :: J_C_EPS_AD = 18
  integer, parameter :: J_C_EPS_S = 19
  integer, parameter :: J_KAP_AD = 20
  integer, parameter :: J_KAP_S = 21
  integer, parameter :: J_OMEGA_ROT = 22

  integer, parameter :: J_LAST = J_OMEGA_ROT

  ! Derived-type definitions

  type, extends (c_eqns_t) :: nad_eqns_t
     private
     type(nad_share_t), pointer  :: sh => null()
     type(nad_trans_t)           :: tr
     real(WP), allocatable       :: coeff(:,:)
     real(WP), allocatable       :: x(:)
     real(WP)                    :: alpha_gr
     real(WP)                    :: alpha_hf
     real(WP)                    :: alpha_rh
     real(WP)                    :: alpha_om
     integer                     :: conv_scheme
   contains
     private
     procedure, public :: stencil
     procedure, public :: A
     procedure, public :: xA
  end type nad_eqns_t

  ! Interfaces

  interface nad_eqns_t
     module procedure nad_eqns_t_
  end interface nad_eqns_t

  ! Access specifiers

  private

  public :: nad_eqns_t

  ! Procedures

contains

  function nad_eqns_t_ (sh, pt_i, md_p, os_p) result (eq)

    type(nad_share_t), pointer, intent(in) :: sh
    type(point_t), intent(in)              :: pt_i
    type(mode_par_t), intent(in)           :: md_p
    type(osc_par_t), intent(in)            :: os_p
    type(nad_eqns_t)                       :: eq

    ! Construct the nad_eqns_t

    eq%sh => sh

    eq%tr = nad_trans_t(sh, pt_i, md_p, os_p)

    if (os_p%cowling_approx) then
       eq%alpha_gr = 0._WP
    else
       eq%alpha_gr = 1._WP
    endif

    if (os_p%narf_approx) then
       eq%alpha_hf = 0._WP
    else
       eq%alpha_hf = 1._WP
    endif

    if (os_p%eddington_approx) then
       eq%alpha_rh = 1._WP
    else
       eq%alpha_rh = 0._WP
    endif

    select case (os_p%time_factor)
    case ('OSC')
       eq%alpha_om = 1._WP
    case ('EXP')
       eq%alpha_om = -1._WP
    case default
       $ABORT(Invalid time_factor)
    end select

    select case (os_p%conv_scheme)
    case ('FROZEN_PESNELL_1')
       eq%conv_scheme = P1_CONV_SCHEME
    case ('FROZEN_PESNELL_4')
       eq%conv_scheme = P4_CONV_SCHEME
    case default
       $ABORT(Invalid conv_scheme)
    end select

    eq%n_e = 6

    ! Finish

    return

  end function nad_eqns_t_

  !****

  subroutine stencil (this, pt)

    class(nad_eqns_t), intent(inout) :: this
    type(point_t), intent(in)        :: pt(:)

    integer :: n_s
    integer :: i

    ! Calculate coefficients at the stencil points

    associate (ml => this%sh%ml)

      call check_model(ml, [ &
           I_V_2,I_AS,I_U,I_C_1,I_GAMMA_1,I_NABLA,I_NABLA_AD,I_DELTA, &
           I_C_LUM,I_C_RAD,I_C_DIF,I_C_THN,I_C_THK, &
           I_C_EPS_AD,I_C_EPS_S,I_KAP_AD,I_KAP_S,I_OMEGA_ROT])

      n_s = SIZE(pt)

      if (ALLOCATED(this%coeff)) deallocate(this%coeff)
      allocate(this%coeff(n_s, J_LAST))

      do i = 1, n_s
         this%coeff(i,J_V) = ml%coeff(I_V_2, pt(i))*pt(i)%x**2
         this%coeff(i,J_V_G) = this%coeff(i,J_V)/ml%coeff(I_GAMMA_1, pt(i))
         this%coeff(i,J_AS) = ml%coeff(I_AS, pt(i))
         this%coeff(i,J_U) = ml%coeff(I_U, pt(i))
         this%coeff(i,J_C_1) = ml%coeff(I_C_1, pt(i))
         this%coeff(i,J_NABLA_AD) = ml%coeff(I_NABLA_AD, pt(i))
         this%coeff(i,J_DNABLA_AD) = ml%dcoeff(I_NABLA_AD, pt(i))
         this%coeff(i,J_NABLA) = ml%coeff(I_NABLA, pt(i))
         this%coeff(i,J_DELTA) = ml%coeff(I_DELTA, pt(i))
         this%coeff(i,J_C_LUM) = ml%coeff(I_C_LUM, pt(i))
         this%coeff(i,J_DC_LUM) = ml%dcoeff(I_C_LUM, pt(i))
         this%coeff(i,J_C_RAD) = ml%coeff(I_C_RAD, pt(i))
         this%coeff(i,J_DC_RAD) = ml%dcoeff(I_C_RAD, pt(i))
         this%coeff(i,J_C_DIF) = ml%coeff(I_C_DIF, pt(i))
         this%coeff(i,J_C_THN) = ml%coeff(I_C_THN, pt(i))
         this%coeff(i,J_DC_THN) = ml%dcoeff(I_C_THN, pt(i))
         this%coeff(i,J_C_THK) = ml%coeff(I_C_THK, pt(i))
         this%coeff(i,J_C_EPS_AD) = ml%coeff(I_C_EPS_AD, pt(i))
         this%coeff(i,J_C_EPS_S) = ml%coeff(I_C_EPS_S, pt(i))
         this%coeff(i,J_KAP_AD) = ml%coeff(I_KAP_AD, pt(i))
         this%coeff(i,J_KAP_S) = ml%coeff(I_KAP_S, pt(i))
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

    class(nad_eqns_t), intent(in) :: this
    integer, intent(in)           :: i
    complex(WP), intent(in)       :: omega
    complex(WP)                   :: A(this%n_e,this%n_e)
    
    ! Evaluate the RHS matrix

    A = this%xA(i, omega)/this%x(i)

    ! Finish

    return

  end function A

  !****

  function xA (this, i, omega)

    class(nad_eqns_t), intent(in) :: this
    integer, intent(in)           :: i
    complex(WP), intent(in)       :: omega
    complex(WP)                   :: xA(this%n_e,this%n_e)

    complex(WP) :: lambda
    complex(WP) :: l_i
    complex(WP) :: omega_c
    complex(WP) :: i_omega_c
    complex(WP) :: f_rh
    complex(WP) :: df_rh
    complex(WP) :: conv_term
         
    ! Evaluate the log(x)-space RHS matrix

    associate ( &
         V => this%coeff(i,J_V), &
         V_g => this%coeff(i,J_V_G), &
         As => this%coeff(i,J_AS), &
         U => this%coeff(i,J_U), &
         c_1 => this%coeff(i,J_C_1), &
         nabla_ad => this%coeff(i,J_NABLA_AD), &
         dnabla_ad => this%coeff(i,J_DNABLA_AD), &
         nabla => this%coeff(i,J_NABLA), &
         delta => this%coeff(i,J_DELTA), &
         c_lum => this%coeff(i,J_C_LUM), &
         dc_lum => this%coeff(i,J_DC_LUM), &
         c_rad => this%coeff(i,J_C_RAD), &
         dc_rad => this%coeff(i,J_DC_RAD), &
         c_dif => this%coeff(i,J_C_DIF), &
         c_thn => this%coeff(i,J_C_THN), &
         dc_thn => this%coeff(i,J_DC_THN), &
         c_thk => this%coeff(i,J_C_THK), &
         c_eps_ad => this%coeff(i,J_C_EPS_AD), &
         c_eps_S => this%coeff(i,J_C_EPS_S), &
         kap_ad => this%coeff(i,J_KAP_AD), &
         kap_S => this%coeff(i,J_KAP_S), &
         Omega_rot => this%coeff(i,J_OMEGA_ROT), &
         x => this%x(i), &
         alpha_gr => this%alpha_gr, &
         alpha_hf => this%alpha_hf, &
         alpha_rh => this%alpha_rh, &
         alpha_om => this%alpha_om)

      lambda = this%sh%lambda(Omega_rot, omega)
      l_i = this%sh%l_i(omega)
    
      omega_c = this%sh%omega_c(Omega_rot, omega)
      i_omega_c = (0._WP,1._WP)*SQRT(CMPLX(alpha_om, KIND=WP))*omega_c

      f_rh = 1._WP - 0.25_WP*alpha_rh*i_omega_c*c_thn
      df_rh = -0.25_WP*alpha_rh*i_omega_c*c_thn*dc_thn/f_rh

      select case (this%conv_scheme)
      case (P1_CONV_SCHEME)
         conv_term = lambda*c_rad*(3._WP + dc_rad)/(c_1*alpha_om*omega_c**2)
      case (P4_CONV_SCHEME)
         conv_term = lambda*(c_lum*(3._WP + dc_lum) - (c_lum - c_rad))/(c_1*alpha_om*omega_c**2)
      case default
         $ABORT(Invalid conv_scheme)
      end select
      
      ! Set up the matrix

      xA(1,1) = V_g - 1._WP - l_i
      xA(1,2) = lambda/(c_1*alpha_om*omega_c**2) - V_g
      xA(1,3) = alpha_gr*(lambda/(c_1*alpha_om*omega_c**2))
      xA(1,4) = alpha_gr*(0._WP)
      xA(1,5) = delta
      xA(1,6) = 0._WP

      xA(2,1) = c_1*alpha_om*omega_c**2 - As
      xA(2,2) = As - U + 3._WP - l_i
      xA(2,3) = alpha_gr*(0._WP)
      xA(2,4) = alpha_gr*(-1._WP)
      xA(2,5) = delta
      xA(2,6) = 0._WP

      xA(3,1) = alpha_gr*(0._WP)
      xA(3,2) = alpha_gr*(0._WP)
      xA(3,3) = alpha_gr*(3._WP - U - l_i)
      xA(3,4) = alpha_gr*(1._WP)
      xA(3,5) = alpha_gr*(0._WP)
      xA(3,6) = alpha_gr*(0._WP)

      xA(4,1) = alpha_gr*(U*As)
      xA(4,2) = alpha_gr*(U*V_g)
      xA(4,3) = alpha_gr*(lambda)
      xA(4,4) = alpha_gr*(-U - l_i + 2._WP)
      xA(4,5) = alpha_gr*(-U*delta)
      xA(4,6) = alpha_gr*(0._WP)

      xA(5,1) = V*(nabla_ad*(U - c_1*alpha_om*omega_c**2) - 4._WP*(nabla_ad - nabla) + c_dif + nabla_ad*dnabla_ad)/f_rh
      xA(5,2) = V*(lambda/(c_1*alpha_om*omega_c**2)*(nabla_ad - nabla) - (c_dif + nabla_ad*dnabla_ad))/f_rh
      xA(5,3) = alpha_gr*(V*lambda/(c_1*alpha_om*omega_c**2)*(nabla_ad - nabla))/f_rh
      xA(5,4) = alpha_gr*(V*nabla_ad)/f_rh
      xA(5,5) = V*nabla*(4._WP*f_rh - kap_S)/f_rh - df_rh - (l_i - 2._WP)
      xA(5,6) = -V*nabla/(c_rad*f_rh)

      xA(6,1) = alpha_hf*lambda*(nabla_ad/nabla - 1._WP)*c_rad - V*c_eps_ad
      xA(6,2) = V*c_eps_ad - lambda*c_rad*alpha_hf*nabla_ad/nabla + conv_term
      xA(6,3) = alpha_gr*conv_term
      xA(6,4) = alpha_gr*(0._WP)
      if (x > 0._WP) then
         xA(6,5) = c_eps_S - alpha_hf*lambda*c_rad/(nabla*V) + i_omega_c*c_thk
      else
         xA(6,5) = -alpha_hf*HUGE(0._WP)
      endif
      xA(6,6) = -1._WP - l_i

    end associate

    ! Apply the variables transformation

    call this%tr%trans_eqns(xA, i, omega)

    ! Finish

    return

  end function xA

end module gyre_nad_eqns
