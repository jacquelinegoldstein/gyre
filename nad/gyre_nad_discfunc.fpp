! Module   : gyre_ad_discfunc
! Purpose  : nonadiabatic discriminant root finding
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

module gyre_nad_discfunc

  ! Uses

  use core_kinds
  use core_func

  use gyre_nad_bvp
  use gyre_ext_arith

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type, extends(func_t) :: nad_discfunc_t
     private
     type(nad_bvp_t), pointer :: bp
   contains 
     private
     procedure, public :: init
     procedure, public :: eval_c
  end type nad_discfunc_t

  ! Access specifiers

  private

  public :: nad_discfunc_t

  ! Procedures

contains

  subroutine init (this, bp)
    
    class(nad_discfunc_t), intent(out)     :: this
    type(nad_bvp_t), intent(inout), target :: bp

    ! Initialize the nad_discfunc

    this%bp => bp

    ! Finish

    return

  end subroutine init

!****

  function eval_c (this, z) result (f_z)

    class(nad_discfunc_t), intent(inout) :: this
    complex(WP), intent(in)              :: z
    complex(WP)                          :: f_z

    ! Evaluate the normalized discriminant

    f_z = cmplx(this%bp%discrim(z, norm=.TRUE.))

    ! Finish

    return

  end function eval_c

end module gyre_nad_discfunc
