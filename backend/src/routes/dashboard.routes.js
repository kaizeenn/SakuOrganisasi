import { Router } from 'express';
import dashboardController from '../controllers/dashboard.controller.js';
import authenticate from '../middlewares/auth.js';

const router = Router();

router.use(authenticate);

router.get('/summary', dashboardController.summary);
router.get('/by-category', dashboardController.byCategory);
router.get('/monthly-trend', dashboardController.monthlyTrend);

export default router;
