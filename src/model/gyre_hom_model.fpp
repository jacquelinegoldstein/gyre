! Module   : gyre_hom_model
! Purpose  : stellar homogeneous compressible model
!
! Copyright 2013-2016 Rich Townsend
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

module gyre_hom_model

  ! Uses

  use core_kinds
  use core_parallel

  use gyre_model
  use gyre_model_par

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  $define $PROC_DECL $sub
    $local $NAME $1
    procedure :: ${NAME}_1_
    procedure :: ${NAME}_v_
  $endsub

  type, extends (model_t) :: hom_model_t
     private
     real(WP) :: x_i_
     real(WP) :: x_o_
     real(WP) :: Gamma_1_
     real(WP) :: Omega_rot_
   contains
     private
     $PROC_DECL(V_2)
     $PROC_DECL(As)
     $PROC_DECL(U)
     $PROC_DECL(dU)
     $PROC_DECL(c_1)
     $PROC_DECL(Gamma_1)
     $PROC_DECL(delta)
     $PROC_DECL(nabla_ad)
     $PROC_DECL(dnabla_ad)
     $PROC_DECL(nabla)
     $PROC_DECL(beta_rad)
     $PROC_DECL(c_rad)
     $PROC_DECL(dc_rad)
     $PROC_DECL(c_thm)
     $PROC_DECL(c_dif)
     $PROC_DECL(c_eps_ad)
     $PROC_DECL(c_eps_S)
     $PROC_DECL(kappa_ad)
     $PROC_DECL(kappa_S)
     $PROC_DECL(Omega_rot)
     $PROC_DECL(dOmega_rot)
     procedure, public :: x_i
     procedure, public :: x_o
     procedure, public :: x_base
  end type hom_model_t

  ! Interfaces

  interface hom_model_t
     module procedure hom_model_t_
  end interface hom_model_t

  ! Access specifiers

  private

  public :: hom_model_t

  ! Procedures

contains

  function hom_model_t_ (ml_p) result (ml)

    type(model_par_t), intent(in) :: ml_p
    type(hom_model_t)             :: ml

    ! Construct the hom_model_t

    ml%x_i_ = ml_p%x_i
    ml%x_o_ = ml_p%x_o

    ml%Gamma_1_ = ml_p%Gamma_1

    if (ml_p%uniform_rot) then
       ml%Omega_rot_ = ml_p%Omega_rot
    else
       ml%Omega_rot_ = 0._WP
    endif

    ml%n_s = 1

    ! Finish

    return

  end function hom_model_t_

  !****

  function V_2_1_ (this, s, x) result (V_2)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: V_2

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Calculate V_2

    if (x /= 1. _WP) then
       V_2 = 2._WP/(1._WP - x**2)
    else
       V_2 = 2._WP/EPSILON(0._WP)
    endif

    ! Finish

    return

  end function V_2_1_

  !****

  function As_1_ (this, s, x) result (As)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: As

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Calculate As

    As = -this%V_2(s, x)*x**2/this%Gamma_1_

    ! Finish

    return

  end function As_1_

  !****

  function U_1_ (this, s, x) result (U)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: U

    ! Calculate U

    U = 3._WP

    ! Finish

    return

  end function U_1_

  !****

  function dU_1_ (this, s, x) result (dU)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: dU

    ! Calculate dlnU/dlnx

    dU = 0._WP

    ! Finish

    return

  end function dU_1_

  !****

  function c_1_1_ (this, s, x) result (c_1)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: c_1

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Calculate c_1

    c_1 = 1._WP

    ! Finish

    return

  end function c_1_1_

  !****

  function Gamma_1_1_ (this, s, x) result (Gamma_1)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: Gamma_1

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Calculate Gamma_1

    Gamma_1 = this%Gamma_1_

    ! Finish

    return

  end function Gamma_1_1_

  !****

  function delta_1_ (this, s, x) result (delta)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: delta

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Calculate delta (assume ideal gas)

    delta = 1._WP

    ! Finish

    return

  end function delta_1_

  !****

  function nabla_ad_1_ (this, s, x) result (nabla_ad)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: nabla_ad

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Calculate nabla_ad (assume ideal gas)

    nabla_ad = 2._WP/5._WP

    ! Finish

    return

  end function nabla_ad_1_

  !****

  function dnabla_ad_1_ (this, s, x) result (dnabla_ad)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: dnabla_ad

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Calculate dlnnabla_ad/dlnx

    dnabla_ad = 0._WP

    ! Finish

    return

  end function dnabla_ad_1_

  !****

  function Omega_rot_1_ (this, s, x) result (Omega_rot)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: Omega_rot

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Calculate Omega_rot

    Omega_rot = this%Omega_rot_

    ! Finish

    return

  end function Omega_rot_1_

  !****

  function dOmega_rot_1_ (this, s, x) result (dOmega_rot)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: dOmega_rot

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Calculate dlnOmega_rot/dlnx

    dOmega_rot = 0._WP

    ! Finish

    return

  end function dOmega_rot_1_

  !****

  $define $PROC_1_NULL $sub

  $local $NAME $1

  function ${NAME}_1_ (this, s, x) result (${NAME})

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP), intent(in)           :: x
    real(WP)                       :: $NAME

    $ABORT(Homogeneous model does not define $NAME)

    ! (This line to prevent unset warnings)

    $NAME = 0._WP

    ! Finish

    return

  end function ${NAME}_1_

  $endsub

  $PROC_1_NULL(nabla)
  $PROC_1_NULL(beta_rad)
  $PROC_1_NULL(c_rad)
  $PROC_1_NULL(dc_rad)
  $PROC_1_NULL(c_thm)
  $PROC_1_NULL(c_dif)
  $PROC_1_NULL(c_eps_ad)
  $PROC_1_NULL(c_eps_S)
  $PROC_1_NULL(kappa_ad)
  $PROC_1_NULL(kappa_S)

  !****

  $define $PROC_V $sub

  $local $NAME $1

  function ${NAME}_v_ (this, s, x) result (${NAME})

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s(:)
    real(WP), intent(in)           :: x(:)
    real(WP)                       :: ${NAME}(SIZE(s))

    integer :: k

    $CHECK_BOUNDS(SIZE(x),SIZE(s))

    ! Evaluate $NAME

    !$OMP PARALLEL DO
    do k = 1, SIZE(s)
       ${NAME}(k) = this%${NAME}(s(k), x(k))
    end do

    ! Finish

    return

  end function ${NAME}_v_

  $endsub

  $PROC_V(V_2)
  $PROC_V(As)
  $PROC_V(U)
  $PROC_V(dU)
  $PROC_V(c_1)
  $PROC_V(Gamma_1)
  $PROC_V(delta)
  $PROC_V(nabla_ad)
  $PROC_V(dnabla_ad)
  $PROC_V(nabla)
  $PROC_V(beta_rad)
  $PROC_V(c_rad)
  $PROC_V(dc_rad)
  $PROC_V(c_thm)
  $PROC_V(c_dif)
  $PROC_V(c_eps_ad)
  $PROC_V(c_eps_S)
  $PROC_V(kappa_ad)
  $PROC_V(kappa_S)
  $PROC_V(Omega_rot)
  $PROC_V(dOmega_rot)

  !****

  function x_i (this, s)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)             :: s
    real(WP)                        :: x_i

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Return the inner x value for segment s

    x_i = this%x_i_

    ! Finish

    return

  end function x_i

  !****

  function x_o (this, s)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)            :: s
    real(WP)                       :: x_o

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Return the outer x value for segment s

    x_o = this%x_o_

    ! Finish

    return

  end function x_o

  !****

  function x_base (this, s)

    class(hom_model_t), intent(in) :: this
    integer, intent(in)             :: s
    real(WP), allocatable           :: x_base(:)

    $ASSERT_DEBUG(s == 1,Invalid segment index)

    ! Return the model grid for segment s

    x_base = [this%x_i_,this%x_o_]

    ! Finish

    return

  end function x_base

end module gyre_hom_model
