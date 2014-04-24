! Module   : gyre_lib
! Purpose  : library interface for use in MESA
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

module gyre_lib

  ! Uses

  use core_kinds
  use core_parallel

  use gyre_constants
  use gyre_bvp
  use gyre_ad_bvp
  use gyre_rad_bvp
  use gyre_nad_bvp
  use gyre_model
  use gyre_evol_model
  use gyre_mesa_file
  use gyre_modepar
  use gyre_oscpar
  use gyre_gridpar
  use gyre_numpar
  use gyre_scanpar
  use gyre_search
  use gyre_mode
  use gyre_input
  use gyre_util

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Module variables

  class(model_t), pointer, save :: ml_m => null()
  real(WP), allocatable, save   :: x_ml_m(:)

  ! Access specifiers

  private

  public :: WP

  public :: G_GRAVITY
  public :: C_LIGHT
  public :: A_RADIATION
  
  public :: M_SUN
  public :: R_SUN
  public :: L_SUN

  public :: mode_t
  public :: gyre_init
  public :: gyre_read_model
  public :: gyre_set_model
  public :: gyre_get_modes

  ! Procedures

contains

  subroutine gyre_init ()

    ! Initialize

    call init_parallel()

    call set_log_level('WARN')

    ! Finish

    return

  end subroutine gyre_init

!****

  subroutine gyre_final()

    ! Finalize

    if(ASSOCIATED(ml_m)) then
       call ml_m%final()
       deallocate(ml_m)
    endif

    if(ALLOCATED(x_ml_m)) deallocate(x_ml_m)

    call final_parallel()

    ! Finish

    return

  end subroutine gyre_final

!****

  subroutine gyre_read_model (file, deriv_type)

    character(LEN=*), intent(in) :: file
    character(LEN=*), intent(in) :: deriv_type

    type(evol_model_t) :: ec

    ! Read the model

    if(ASSOCIATED(ml_m)) then
       call ml_m%final()
       deallocate(ml_m)
    endif

    call read_mesa_model(file, deriv_type, ec, x_ml_m)

    allocate(ml_m, SOURCE=ec)

    ! Finish

    return

  end subroutine gyre_read_model
  
!****

  subroutine gyre_set_model (M_star, R_star, L_star, r, w, p, rho, T, &
                             N2, Gamma_1, nabla_ad, delta, nabla,  &
                             kappa, kappa_rho, kappa_T, &
                             epsilon, epsilon_rho, epsilon_T, &
                             Omega_rot, deriv_type)

    real(WP), intent(in)         :: M_star
    real(WP), intent(in)         :: R_star
    real(WP), intent(in)         :: L_star
    real(WP), intent(in)         :: r(:)
    real(WP), intent(in)         :: w(:)
    real(WP), intent(in)         :: p(:)
    real(WP), intent(in)         :: rho(:)
    real(WP), intent(in)         :: T(:)
    real(WP), intent(in)         :: N2(:)
    real(WP), intent(in)         :: Gamma_1(:)
    real(WP), intent(in)         :: nabla_ad(:)
    real(WP), intent(in)         :: delta(:)
    real(WP), intent(in)         :: nabla(:)
    real(WP), intent(in)         :: kappa(:)
    real(WP), intent(in)         :: kappa_rho(:)
    real(WP), intent(in)         :: kappa_T(:)
    real(WP), intent(in)         :: epsilon(:)
    real(WP), intent(in)         :: epsilon_rho(:)
    real(WP), intent(in)         :: epsilon_T(:)
    real(WP), intent(in)         :: Omega_rot(:)
    character(LEN=*), intent(in) :: deriv_type

    real(WP), allocatable :: m(:)
    logical               :: add_center

    ! Allocate the model

    if(ASSOCIATED(ml_m)) then
       call ml_m%final()
       deallocate(ml_m)
    endif

    allocate(evol_model_t::ml_m)

    ! Set the model by storing coefficients

    m = w/(1._WP+w)*M_star

    add_center = r(1) /= 0._WP .OR. m(1) /= 0._WP

    allocate(ml_m, SOURCE=evol_model_t(M_star, R_star, L_star, r, m, p, rho, T, N2, &
                                       Gamma_1, nabla_ad, delta, Omega_rot, &
                                       nabla, kappa, kappa_rho, kappa_T, &
                                       epsilon, epsilon_rho, epsilon_T, &
                                       deriv_type, add_center))

    if(add_center) then
       x_ml_m = [0._WP,r/R_star]
    else
       x_ml_m = r/R_star
    endif

    ! Finish

    return

  end subroutine gyre_set_model

!****

  subroutine gyre_get_modes (l, file, non_ad, user_sub, ipar, rpar)

    integer, intent(in)          :: l
    character(LEN=*), intent(in) :: file
    logical, intent(in)          :: non_ad
    interface
       subroutine user_sub (md, ipar, rpar, retcode)
         import mode_t
         import WP
         type(mode_t), intent(in) :: md
         integer, intent(inout)   :: ipar(:)
         real(WP), intent(inout)  :: rpar(:)
         integer, intent(out)     :: retcode
       end subroutine user_sub
    end interface
    integer, intent(inout)  :: ipar(:)
    real(WP), intent(inout) :: rpar(:)

    integer                      :: unit
    type(modepar_t), allocatable :: mp(:)
    type(oscpar_t), allocatable  :: op(:)
    type(numpar_t), allocatable  :: np(:)
    type(scanpar_t), allocatable :: sp(:)
    type(gridpar_t), allocatable :: shoot_gp(:)
    type(gridpar_t), allocatable :: recon_gp(:)
    integer                      :: i
    type(oscpar_t), allocatable  :: op_sel(:)
    type(numpar_t), allocatable  :: np_sel(:)
    type(gridpar_t), allocatable :: shoot_gp_sel(:)
    type(gridpar_t), allocatable :: recon_gp_sel(:)
    type(scanpar_t), allocatable :: sp_sel(:)
    real(WP), allocatable        :: omega(:)
    class(bvp_t), allocatable    :: ad_bp
    class(bvp_t), allocatable    :: nad_bp
    type(mode_t), allocatable    :: md(:)
    integer                      :: j
    integer                      :: retcode

    $ASSERT(ASSOCIATED(ml_m),No model provided)

    ! Read parameters

    open(NEWUNIT=unit, FILE=file, STATUS='OLD')

    call read_modepar(unit, mp)
    call read_oscpar(unit, op)
    call read_numpar(unit, np)
    call read_shoot_gridpar(unit, shoot_gp)
    call read_recon_gridpar(unit, recon_gp)
    call read_scanpar(unit, sp)

    close(unit)

    ! Loop through oscpars

    op_loop : do i = 1, SIZE(mp)

       if (mp(i)%l == l) then

          ! Select parameters according to tags

          call select_par(op, mp(i)%tag, op_sel, last=.TRUE.)
          call select_par(np, mp(i)%tag, np_sel, last=.TRUE.)
          call select_par(shoot_gp, mp(i)%tag, shoot_gp_sel)
          call select_par(recon_gp, mp(i)%tag, recon_gp_sel)
          call select_par(sp, mp(i)%tag, sp_sel)

          $ASSERT(SIZE(op_sel) == 1,No matching num parameters)
          $ASSERT(SIZE(np_sel) == 1,No matching num parameters)
          $ASSERT(SIZE(shoot_gp_sel) >= 1,No matching shoot_grid parameters)
          $ASSERT(SIZE(recon_gp_sel) >= 1,No matching recon_grid parameters)
          $ASSERT(SIZE(sp_sel) >= 1,No matching scan parameters)

          ! Set up the frequency array

          call build_scan(sp_sel, ml_m, mp(i), op_sel(1), shoot_gp_sel, x_ml_m, omega)

          ! Store the frequency range in shoot_gp_sel

          shoot_gp_sel%omega_a = MINVAL(omega)
          shoot_gp_sel%omega_b = MAXVAL(omega)

          ! Set up the bvp's

          if(ALLOCATED(ad_bp)) deallocate(ad_bp)

          if(mp(i)%l == 0 .AND. np_sel(1)%reduce_order) then
             allocate(ad_bp, SOURCE=rad_bvp_t(ml_m, mp(i), op_sel(1), np_sel(1), shoot_gp_sel, recon_gp_sel, x_ml_m))
          else
             allocate(ad_bp, SOURCE=ad_bvp_t(ml_m, mp(i), op_sel(1), np_sel(1), shoot_gp_sel, recon_gp_sel, x_ml_m))
          endif

          if (non_ad) then
             allocate(nad_bp, SOURCE=nad_bvp_t(ml_m, mp(i), op_sel(1), np_sel(1), shoot_gp_sel, recon_gp_sel, x_ml_m))
          endif

          ! Find modes

          call scan_search(ad_bp, omega, md)

          if (non_ad) call prox_search(nad_bp, md)

          $if ($GFORTRAN_PR57922)

          select type (ad_bp)
          type is (rad_bvp_t)
             call ad_bp%final()
          type is (ad_bvp_t)
             call ad_bp%final()
          class default
             $ABORT(Invalid type)
          end select

          if (non_ad) then
             select type (nad_bp)
             type is (nad_bvp_t)
                call nad_bp%final()
             class default
                $ABORT(Invalid type)
             end select
          endif

          $endif

          deallocate(ad_bp)
          
          if (non_ad) deallocate(nad_bp)

          ! Process the modes

          retcode = 0

          mode_loop : do j = 1,SIZE(md)
             if(retcode == 0) then
                call user_sub(md(j), ipar, rpar, retcode)
             endif
             $if($GFORTRAN_PR57922)
             call md(j)%final()
             $endif
          end do mode_loop

       end if

       ! Loop around

    end do op_loop

    ! Finish

    return

  end subroutine gyre_get_modes

end module gyre_lib
