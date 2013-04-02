! Module   : gyre_hom_mech_coeffs
! Purpose  : mechanical structure coefficients for homogeneous compressible models
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

module gyre_hom_mech_coeffs

  ! Uses

  use core_kinds
  use core_parallel

  use gyre_mech_coeffs

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  $define $PROC_DECL $sub
    $local $NAME $1
    procedure :: get_${NAME}_1
    procedure :: get_${NAME}_v
  $endsub

  type, extends(mech_coeffs_t) :: hom_mech_coeffs_t
     private
     real(WP) :: dt_Gamma_1
   contains
     private
     procedure, public :: init
     $PROC_DECL(V)
     $PROC_DECL(As)
     $PROC_DECL(U)
     $PROC_DECL(c_1)
     $PROC_DECL(Gamma_1)
     procedure, public :: conv_freq
  end type hom_mech_coeffs_t

  ! Interfaces

  $if($MPI)

  interface bcast
     module procedure bcast_mc
  end interface bcast

  $endif

  ! Access specifiers

  private

  public :: hom_mech_coeffs_t
  $if($MPI)
  public :: bcast
  $endif

  ! Procedures

contains

  subroutine init (this, Gamma_1)

    class(hom_mech_coeffs_t), intent(out) :: this
    real(WP), intent(in)                  :: Gamma_1

    ! Initialize the mech_coeffs

    this%dt_Gamma_1 = Gamma_1

    ! Finish

    return

  end subroutine init

!****

  $if($MPI)

  subroutine bcast_mc (mc, root_rank)

    class(hom_mech_coeffs_t), intent(inout) :: mc
    integer, intent(in)                     :: root_rank

    ! Broadcast the mech_coeffs

    call bcast(mc%dt_Gamma_1, root_rank)

    ! Finish

    return

  end subroutine bcast_mc

  $endif

!****

  function get_V_1 (this, x) result (V)

    class(hom_mech_coeffs_t), intent(in) :: this
    real(WP), intent(in)                 :: x
    real(WP)                             :: V

    real(WP) :: xi
    real(WP) :: Theta
    real(WP) :: dTheta

    ! Calculate V

    xi = SQRT(6._WP)*x

    Theta = 1._WP - xi**2/6._WP
    dTheta = -xi/3._WP

    V = -xi*dTheta/Theta

    ! Finish

    return

  end function get_V_1

!****
  
  function get_V_v (this, x) result (V)

    class(hom_mech_coeffs_t), intent(in) :: this
    real(WP), intent(in)                 :: x(:)
    real(WP)                             :: V(SIZE(x))

    integer :: i

    ! Calculate V

    x_loop : do i = 1,SIZE(x)
       V(i) = this%V(x(i))
    end do x_loop

    ! Finish

    return

  end function get_V_v

!****

  function get_As_1 (this, x) result (As)

    class(hom_mech_coeffs_t), intent(in) :: this
    real(WP), intent(in)                 :: x
    real(WP)                             :: As

    ! Calculate As

    As = -this%V(x)/this%dt_Gamma_1

    ! Finish

    return

  end function get_As_1

!****
  
  function get_As_v (this, x) result (As)

    class(hom_mech_coeffs_t), intent(in) :: this
    real(WP), intent(in)                 :: x(:)
    real(WP)                             :: As(SIZE(x))

    integer :: i

    ! Calculate As

    x_loop : do i = 1,SIZE(x)
       As(i) = this%As(x(i))
    end do x_loop

    ! Finish

    return

  end function get_As_v

!****

  function get_U_1 (this, x) result (U)

    class(hom_mech_coeffs_t), intent(in) :: this
    real(WP), intent(in)                 :: x
    real(WP)                             :: U

    ! Calculate U

    U = 3._WP

    ! Finish

    return

  end function get_U_1

!****
  
  function get_U_v (this, x) result (U)

    class(hom_mech_coeffs_t), intent(in) :: this
    real(WP), intent(in)                 :: x(:)
    real(WP)                             :: U(SIZE(x))

    integer :: i

    ! Calculate U

    x_loop : do i = 1,SIZE(x)
       U(i) = this%U(x(i))
    end do x_loop

    ! Finish

    return

  end function get_U_v

!****

  function get_c_1_1 (this, x) result (c_1)

    class(hom_mech_coeffs_t), intent(in) :: this
    real(WP), intent(in)                 :: x
    real(WP)                             :: c_1

    ! Calculate c_1

    c_1 = 1._WP

    ! Finish

    return

  end function get_c_1_1

!****
  
  function get_c_1_v (this, x) result (c_1)

    class(hom_mech_coeffs_t), intent(in) :: this
    real(WP), intent(in)                 :: x(:)
    real(WP)                             :: c_1(SIZE(x))

    integer :: i

    ! Calculate c_1

    x_loop : do i = 1,SIZE(x)
       c_1(i) = this%c_1(x(i))
    end do x_loop

    ! Finish

    return

  end function get_c_1_v

!****

  function get_Gamma_1_1 (this, x) result (Gamma_1)

    class(hom_mech_coeffs_t), intent(in) :: this
    real(WP), intent(in)                 :: x
    real(WP)                             :: Gamma_1

    ! Calculate Gamma_1

    Gamma_1 = this%dt_Gamma_1

    ! Finish

    return

  end function get_Gamma_1_1

!****
  
  function get_Gamma_1_v (this, x) result (Gamma_1)

    class(hom_mech_coeffs_t), intent(in) :: this
    real(WP), intent(in)                 :: x(:)
    real(WP)                             :: Gamma_1(SIZE(x))

    integer :: i

    ! Calculate Gamma_1
    
    x_loop : do i = 1,SIZE(x)
       Gamma_1(i) = this%Gamma_1(x(i))
    end do x_loop

    ! Finish

    return

  end function get_Gamma_1_v

!****

  function conv_freq (this, freq, from_units, to_units)

    class(hom_mech_coeffs_t), intent(in) :: this
    complex(WP), intent(in)              :: freq
    character(LEN=*), intent(in)         :: from_units
    character(LEN=*), intent(in)         :: to_units
    complex(WP)                          :: conv_freq

    ! Convert the frequency

    conv_freq = freq/freq_scale(from_units)*freq_scale(to_units)

    ! Finish

    return

  contains

    function freq_scale (units)

      character(LEN=*), intent(in) :: units
      real(WP)                     :: freq_scale

      ! Calculate the scale factor to convert a dimensionless angular
      ! frequency to a dimensioned frequency

      select case (units)
      case ('NONE')
         freq_scale = 1._WP
      case default
         $ABORT(Invalid units)
      end select

      ! Finish

      return

    end function freq_scale

  end function conv_freq

end module gyre_hom_mech_coeffs
